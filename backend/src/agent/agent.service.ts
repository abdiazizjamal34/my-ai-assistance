import { AgentActionStatus } from "@prisma/client";

import { HttpError } from "../middleware/error-handler";
import { env } from "../config/env";
import { MemoryCandidate } from "../memory/memory.types";
import { ActionLogService } from "./action-log.service";
import {
  AgentContext,
  AIProvider,
  HistoryTurn,
  ToolResult,
} from "./agent.types";
import { buildSystemPrompt } from "./prompts/system-prompt";
import { ToolRegistry } from "./tool-registry";
import { ConversationService } from "./conversation.service";

export type AgentChatResult = {
  message: string;
  conversationId: string;
  actions: Array<{ tool: string; success: boolean }>;
  toolCalls: Array<{ name: string; success: boolean }>;
  memoryUsed: boolean;
  memoryCandidates: MemoryCandidate[];
};

export class AgentService {
  constructor(
    private readonly provider: AIProvider,
    private readonly tools: ToolRegistry,
    private readonly actionLog: ActionLogService,
    private readonly conversations: ConversationService,
  ) {}

  async chat(
    userId: string,
    message: string,
    conversationId?: string,
  ): Promise<AgentChatResult> {
    if (!message.trim()) throw new HttpError(400, "message is required.");

    const conversation = await this.conversations.ensureConversation(
      userId,
      conversationId,
      message,
    );

    // Fetch history BEFORE appending the current message so the LLM sees
    // the current message exactly once.
    const history: HistoryTurn[] = await this.conversations.getRecentMessages(
      conversation.id,
      12,
    );

    await this.conversations.appendMessage({
      conversationId: conversation.id,
      role: "user",
      content: message,
    });

    const context = await this.tools.getContext(userId, message);
    const systemPrompt = buildSystemPrompt({
      assistantName:
        (context.assistantProfile as { name?: string })?.name ?? "Chief",
      personality:
        (context.assistantProfile as { personality?: string })?.personality ??
        "FRIENDLY",
      communicationStyle:
        (context.assistantProfile as { communicationStyle?: string })
          ?.communicationStyle ?? "BALANCED",
      responseLength:
        (context.assistantProfile as { responseLength?: string })
          ?.responseLength ?? "BALANCED",
      proactivity:
        (context.assistantProfile as { proactivity?: string })?.proactivity ??
        "MEDIUM",
      memoryContext: context.memories.formattedContext,
    });

    let providerResponse;
    try {
      providerResponse = await this.provider.generateResponse({
        systemPrompt,
        userMessage: message,
        context,
        tools: this.tools.definitions(),
        history,
      });
    } catch (error) {
      await this.logFailure(userId, conversation.id, error);
      throw new HttpError(
        502,
        "I could not reach the assistant provider right now.",
      );
    }

    const toolResults: ToolResult[] = [];
    for (const toolCall of providerResponse.toolCalls) {
      const result = await this.tools.execute(userId, toolCall);
      toolResults.push(result);
      await this.logToolCall(userId, conversation.id, toolCall, result);
    }

    if (this.hasForgetIntent(message)) {
      await this.handleForgetIntent(userId, conversation.id, toolResults);
    }

    const candidates = await this.resolveCandidate(
      userId,
      message,
      toolResults,
      conversation.id,
    );

    const memoryUsed = context.memories.memories.length > 0;
    const baseResult = {
      conversationId: conversation.id,
      toolCalls: toolResults.map((r) => ({
        name: r.toolCall.name,
        success: r.ok,
      })),
      actions: toolResults.map((r) => ({
        tool: r.toolCall.name,
        success: r.ok,
      })),
      memoryUsed,
      memoryCandidates: candidates,
    };

    if (!toolResults.length) {
      const finalMessage =
        providerResponse.message ||
        "I'm not sure how to help with that yet. Could you rephrase?";
      await this.conversations.appendMessage({
        conversationId: conversation.id,
        role: "assistant",
        content: finalMessage,
        metadata: { toolCalls: [], memoryUsed },
      });
      return { message: finalMessage, ...baseResult };
    }

    try {
      const finalResponse = await this.provider.generateResponse({
        systemPrompt,
        userMessage: message,
        context,
        tools: this.tools.definitions(),
        toolResults,
        history,
      });
      const finalMessage =
        finalResponse.message ||
        (toolResults.every((r) => r.ok)
          ? "The action completed successfully."
          : "I could not complete that action right now.");
      await this.conversations.appendMessage({
        conversationId: conversation.id,
        role: "assistant",
        content: finalMessage,
        metadata: { toolCalls: baseResult.toolCalls, memoryUsed },
      });
      return { message: finalMessage, ...baseResult };
    } catch (error) {
      await this.logFailure(userId, conversation.id, error);
      const fallback = toolResults.every((r) => r.ok)
        ? "The action completed successfully."
        : "I could not complete that action right now.";
      await this.conversations.appendMessage({
        conversationId: conversation.id,
        role: "assistant",
        content: fallback,
        metadata: {
          toolCalls: baseResult.toolCalls,
          memoryUsed,
          degraded: true,
        },
      });
      return { message: fallback, ...baseResult };
    }
  }

  async *chatStream(
    userId: string,
    message: string,
    conversationId?: string,
  ): AsyncIterable<
    | { type: "meta"; conversationId: string }
    | { type: "tool"; name: string; success: boolean }
    | { type: "text"; delta: string }
    | {
        type: "done";
        message: string;
        memoryCandidates: MemoryCandidate[];
      }
    | { type: "error"; message: string }
  > {
    if (!message.trim()) {
      yield { type: "error", message: "message is required." };
      return;
    }

    const conversation = await this.conversations.ensureConversation(
      userId,
      conversationId,
      message,
    );

    // Fetch history BEFORE appending the current message.
    const history: HistoryTurn[] = await this.conversations.getRecentMessages(
      conversation.id,
      12,
    );

    await this.conversations.appendMessage({
      conversationId: conversation.id,
      role: "user",
      content: message,
    });

    yield { type: "meta", conversationId: conversation.id };

    const context = await this.tools.getContext(userId, message);
    const systemPrompt = buildSystemPrompt({
      assistantName:
        (context.assistantProfile as { name?: string })?.name ?? "Chief",
      personality:
        (context.assistantProfile as { personality?: string })?.personality ??
        "FRIENDLY",
      communicationStyle:
        (context.assistantProfile as { communicationStyle?: string })
          ?.communicationStyle ?? "BALANCED",
      responseLength:
        (context.assistantProfile as { responseLength?: string })
          ?.responseLength ?? "BALANCED",
      proactivity:
        (context.assistantProfile as { proactivity?: string })?.proactivity ??
        "MEDIUM",
      memoryContext: context.memories.formattedContext,
    });

    let initial;
    try {
      initial = await this.provider.generateResponse({
        systemPrompt,
        userMessage: message,
        context,
        tools: this.tools.definitions(),
        history,
      });
    } catch (error) {
      await this.logFailure(userId, conversation.id, error);
      yield {
        type: "error",
        message: "I could not reach the assistant provider right now.",
      };
      return;
    }

    const toolResults: ToolResult[] = [];
    for (const toolCall of initial.toolCalls) {
      const result = await this.tools.execute(userId, toolCall);
      toolResults.push(result);
      await this.logToolCall(userId, conversation.id, toolCall, result);
      yield { type: "tool", name: toolCall.name, success: result.ok };
    }

    if (/\bforget\b/i.test(message)) {
      for (const result of toolResults) {
        if (result.toolCall.name !== "search_memories" || !result.ok) continue;
        if (!Array.isArray(result.output)) continue;
        for (const memory of result.output) {
          const memoryId =
            memory && typeof memory === "object"
              ? (memory as Record<string, unknown>).id
              : undefined;
          if (typeof memoryId !== "string") continue;
          const archiveCall = {
            name: "archive_memory",
            arguments: { memoryId },
          };
          const archiveResult = await this.tools.execute(userId, archiveCall);
          toolResults.push(archiveResult);
          await this.logToolCall(
            userId,
            conversation.id,
            archiveCall,
            archiveResult,
          );
          yield {
            type: "tool",
            name: archiveCall.name,
            success: archiveResult.ok,
          };
        }
      }
    }

    const candidates = await this.resolveCandidate(
      userId,
      message,
      toolResults,
      conversation.id,
    );

    const canStream = typeof this.provider.streamResponse === "function";
    const shouldNarrate = toolResults.length > 0;

    let finalMessage = "";

    if (canStream) {
      try {
        for await (const chunk of this.provider.streamResponse!({
          systemPrompt,
          userMessage: message,
          context,
          tools: this.tools.definitions(),
          history,
          ...(shouldNarrate ? { toolResults } : {}),
        })) {
          if (chunk.type === "text") {
            yield { type: "text", delta: chunk.delta };
          } else if (chunk.type === "done") {
            finalMessage = chunk.message;
          } else if (chunk.type === "error") {
            yield { type: "error", message: chunk.message };
            return;
          }
        }
      } catch (error) {
        await this.logFailure(userId, conversation.id, error);
        yield {
          type: "error",
          message: "The response stream failed midway.",
        };
        return;
      }
    } else {
      const fallbackMessage =
        initial.message ||
        (shouldNarrate && toolResults.every((r) => r.ok)
          ? "The action completed successfully."
          : "I could not complete that action right now.");
      finalMessage = fallbackMessage;
      if (fallbackMessage.trim().length > 0) {
        yield { type: "text", delta: fallbackMessage };
      }
    }

    if (finalMessage.trim().length === 0) {
      finalMessage =
        shouldNarrate && toolResults.every((r) => r.ok)
          ? "Done."
          : "I'm not sure how to help with that yet.";
    }

    await this.conversations.appendMessage({
      conversationId: conversation.id,
      role: "assistant",
      content: finalMessage,
      metadata: {
        toolCalls: toolResults.map((r) => ({
          name: r.toolCall.name,
          success: r.ok,
        })),
        memoryUsed: context.memories.memories.length > 0,
      },
    });

    yield {
      type: "done",
      message: finalMessage,
      memoryCandidates: candidates,
    };
  }

  private hasForgetIntent(message: string): boolean {
    return /\bforget\b/i.test(message);
  }

  private async handleForgetIntent(
    userId: string,
    conversationId: string,
    toolResults: ToolResult[],
  ): Promise<void> {
    for (const result of toolResults) {
      if (result.toolCall.name !== "search_memories" || !result.ok) continue;
      if (!Array.isArray(result.output)) continue;
      for (const memory of result.output) {
        const memoryId =
          memory && typeof memory === "object"
            ? (memory as Record<string, unknown>).id
            : undefined;
        if (typeof memoryId !== "string") continue;
        const archiveCall = {
          name: "archive_memory",
          arguments: { memoryId },
        };
        const archiveResult = await this.tools.execute(userId, archiveCall);
        toolResults.push(archiveResult);
        await this.logToolCall(
          userId,
          conversationId,
          archiveCall,
          archiveResult,
        );
      }
    }
  }

  private async logFailure(
    userId: string,
    conversationId: string | undefined,
    error: unknown,
  ) {
    console.error("[agent-provider-error]", {
      message: error instanceof Error ? error.message : String(error),
      stack: error instanceof Error ? error.stack : undefined,
    });
    await this.actionLog.record({
      userId,
      conversationId,
      actionType: "AGENT_REQUEST",
      output: {
        error:
          error instanceof Error ? error.message : "Unknown provider error.",
      },
      status: AgentActionStatus.FAILED,
    });
  }

  private async resolveCandidate(
    userId: string,
    message: string,
    toolResults: ToolResult[],
    conversationId?: string,
  ): Promise<MemoryCandidate[]> {
    if (
      !env.memoryEnabled ||
      toolResults.some((r) =>
        ["save_memory", "update_memory"].includes(r.toolCall.name),
      )
    ) {
      return [];
    }
    try {
      const { candidate, result } = await this.tools.resolveMemoryCandidate(
        userId,
        message,
      );
      if (!candidate) return [];
      if (result) {
        await this.logToolCall(userId, conversationId, result.toolCall, result);
        return result.ok ? [] : [candidate];
      }
      return candidate.decision === "ASK_CONFIRMATION" &&
        env.memoryConfirmationEnabled
        ? [candidate]
        : [];
    } catch (error) {
      console.warn("Memory candidate processing failed.", {
        userId,
        error: error instanceof Error ? error.message : "unknown",
      });
      return [];
    }
  }

  private async logToolCall(
    userId: string,
    conversationId: string | undefined,
    toolCall: { name: string; arguments: Record<string, unknown> },
    result: ToolResult,
  ) {
    const actionStatus =
      !result.ok && result.output === "Unknown tool."
        ? AgentActionStatus.REJECTED
        : result.ok
          ? AgentActionStatus.SUCCESS
          : AgentActionStatus.FAILED;
    await this.actionLog.record({
      userId,
      conversationId,
      actionType: "TOOL_CALL",
      toolName: toolCall.name,
      input: this.safeActionData(toolCall.name, toolCall.arguments),
      output: this.safeActionData(toolCall.name, result.output),
      status: actionStatus,
    });
  }

  private safeActionData(toolName: string, value: unknown): unknown {
    if (!toolName.includes("memory")) return value;
    if (Array.isArray(value)) return { count: value.length };
    if (value && typeof value === "object") {
      const memory = value as Record<string, unknown>;
      return {
        id: memory.id,
        category: memory.category,
        status: memory.status,
      };
    }
    return undefined;
  }
}
