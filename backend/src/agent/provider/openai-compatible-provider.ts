import { env } from "../../config/env";
import {
  AIProvider,
  ProviderRequest,
  ProviderResponse,
  ProviderStreamChunk,
  ToolCall,
  ToolResult,
} from "../agent.types";

type OpenAIMessage =
  | { role: "system"; content: string }
  | { role: "user"; content: string }
  | {
      role: "assistant";
      content: string | null;
      tool_calls?: Array<{
        id: string;
        type: "function";
        function: { name: string; arguments: string };
      }>;
    }
  | { role: "tool"; tool_call_id: string; content: string };

type OpenAITool = {
  type: "function";
  function: {
    name: string;
    description: string;
    parameters: Record<string, unknown>;
  };
};

export class OpenAICompatibleProvider implements AIProvider {
  async generateResponse(request: ProviderRequest): Promise<ProviderResponse> {
    if (env.aiProvider !== "ollama" && !env.aiApiKey) {
      throw new Error("AI provider is not configured.");
    }

    const messages = this.buildMessages(request);
    const tools = this.buildTools(request);

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), env.aiTimeoutMs);

    let response: Response;
    try {
      response = await fetch(
        `${env.aiBaseUrl.replace(/\/$/, "")}/chat/completions`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            ...(env.aiApiKey
              ? { Authorization: `Bearer ${env.aiApiKey}` }
              : {}),
          },
          body: JSON.stringify({
            model: env.aiModel,
            temperature: 0.2,
            messages,
            ...(tools.length ? { tools, tool_choice: "auto" as const } : {}),
          }),
          signal: controller.signal,
        },
      );
    } catch (error) {
      if ((error as { name?: string }).name === "AbortError") {
        throw new Error("AI provider request timed out.");
      }
      throw error;
    } finally {
      clearTimeout(timeout);
    }

    if (!response.ok) {
      const text = await response.text().catch(() => "");
      throw new Error(
        `AI provider returned ${response.status}.${
          text ? ` Body: ${text.slice(0, 500)}` : ""
        }`,
      );
    }

    const payload = (await response.json()) as {
      choices?: Array<{
        message?: {
          content?: string | null;
          tool_calls?: Array<{
            id?: string;
            type?: string;
            function?: { name?: string; arguments?: string };
          }>;
        };
      }>;
    };

    const choice = payload.choices?.[0]?.message;

    const toolCalls: ToolCall[] = Array.isArray(choice?.tool_calls)
      ? choice!
          .tool_calls!.map((call, index) => this.parseToolCall(call, index))
          .filter((call): call is ToolCall => call !== null)
      : [];

    return {
      message: typeof choice?.content === "string" ? choice.content : "",
      toolCalls,
    };
  }

  async *streamResponse(
    request: ProviderRequest,
  ): AsyncIterable<ProviderStreamChunk> {
    if (env.aiProvider !== "ollama" && !env.aiApiKey) {
      yield { type: "error", message: "AI provider is not configured." };
      return;
    }

    const messages = this.buildMessages(request);

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), env.aiTimeoutMs);

    let response: Response;
    try {
      response = await fetch(
        `${env.aiBaseUrl.replace(/\/$/, "")}/chat/completions`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            ...(env.aiApiKey
              ? { Authorization: `Bearer ${env.aiApiKey}` }
              : {}),
          },
          body: JSON.stringify({
            model: env.aiModel,
            temperature: 0.2,
            messages,
            stream: true,
          }),
          signal: controller.signal,
        },
      );
    } catch (error) {
      clearTimeout(timeout);
      if ((error as { name?: string }).name === "AbortError") {
        yield { type: "error", message: "AI provider request timed out." };
        return;
      }
      yield {
        type: "error",
        message:
          error instanceof Error ? error.message : "Unknown provider error.",
      };
      return;
    }

    if (!response.ok) {
      clearTimeout(timeout);
      const text = await response.text().catch(() => "");
      yield {
        type: "error",
        message: `AI provider returned ${response.status}.${
          text ? ` Body: ${text.slice(0, 300)}` : ""
        }`,
      };
      return;
    }

    if (!response.body) {
      clearTimeout(timeout);
      yield { type: "error", message: "Provider returned no stream body." };
      return;
    }

    const reader = response.body.getReader();
    const decoder = new TextDecoder();
    let buffer = "";
    let accumulated = "";

    try {
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        buffer += decoder.decode(value, { stream: true });

        let boundary: number;
        while ((boundary = buffer.indexOf("\n\n")) !== -1) {
          const frame = buffer.slice(0, boundary);
          buffer = buffer.slice(boundary + 2);

          for (const line of frame.split("\n")) {
            if (!line.startsWith("data:")) continue;
            const payload = line.slice(5).trim();
            if (!payload || payload === "[DONE]") continue;

            let parsed: {
              choices?: Array<{
                delta?: { content?: string | null };
                finish_reason?: string | null;
              }>;
            };
            try {
              parsed = JSON.parse(payload);
            } catch {
              continue;
            }

            const delta = parsed.choices?.[0]?.delta?.content;
            if (typeof delta === "string" && delta.length > 0) {
              accumulated += delta;
              yield { type: "text", delta };
            }
          }
        }
      }
    } catch (error) {
      if ((error as { name?: string }).name === "AbortError") {
        yield { type: "error", message: "Stream timed out." };
        return;
      }
      yield {
        type: "error",
        message: error instanceof Error ? error.message : "Stream read failed.",
      };
      return;
    } finally {
      clearTimeout(timeout);
      reader.releaseLock();
    }

    yield { type: "done", message: accumulated };
  }

  // --- message construction -------------------------------------------------

  private buildMessages(request: ProviderRequest): OpenAIMessage[] {
    const messages: OpenAIMessage[] = [
      { role: "system", content: request.systemPrompt },
    ];

    // Replay prior turns so the model has conversation context.
    if (request.history?.length) {
      for (const turn of request.history) {
        if (!turn.content.trim()) continue;
        messages.push({ role: turn.role, content: turn.content });
      }
    }

    // Current user message
    messages.push({ role: "user", content: request.userMessage });

    // Tool call replay for the second round-trip.
    if (request.toolResults?.length) {
      const toolCalls = request.toolResults
        .map((r) => r.toolCall)
        .filter(
          (c): c is ToolCall & { id: string } => typeof c.id === "string",
        );

      if (toolCalls.length) {
        messages.push({
          role: "assistant",
          content: null,
          tool_calls: toolCalls.map((call) => ({
            id: call.id,
            type: "function",
            function: {
              name: call.name,
              arguments: JSON.stringify(call.arguments ?? {}),
            },
          })),
        });

        for (const result of request.toolResults) {
          const id = result.toolCall.id;
          if (!id) continue;
          messages.push({
            role: "tool",
            tool_call_id: id,
            content: this.serializeToolOutput(result),
          });
        }
      }
    }

    return messages;
  }

  private buildUserContent(_request: ProviderRequest): string {
    // Kept for API symmetry; current version sends the raw user message.
    return _request.userMessage;
  }

  private serializeToolOutput(result: ToolResult): string {
    if (!result.ok) {
      return JSON.stringify({
        ok: false,
        error:
          typeof result.output === "string"
            ? result.output
            : "Tool execution failed.",
      });
    }
    try {
      return JSON.stringify({ ok: true, data: result.output ?? null });
    } catch {
      return JSON.stringify({ ok: true, data: null });
    }
  }

  // private buildTools(request: ProviderRequest): OpenAITool[] {
  //   return request.tools.map((tool) => ({
  //     type: "function",
  //     function: {
  //       name: tool.name,
  //       description: tool.description,
  //       parameters: tool.parameters,
  //     },
  //   }));
  // }

  private buildTools(request: ProviderRequest): OpenAITool[] {
    return request.tools.map((tool) => {
      const rawParameters = tool.parameters;

      // Normalize empty parameter definitions.
      const parameters: Record<string, unknown> =
        Object.keys(rawParameters).length === 0
          ? {
              type: "object",
              properties: {},
              required: [],
            }
          : rawParameters;

      // Validate the root schema.
      if (
        parameters.type !== "object" ||
        !parameters.properties ||
        typeof parameters.properties !== "object" ||
        Array.isArray(parameters.properties)
      ) {
        throw new Error(
          `Invalid JSON schema for tool "${tool.name}". Expected an object schema with an object properties field.`,
        );
      }

      return {
        type: "function",
        function: {
          name: tool.name,
          description: tool.description,
          parameters,
        },
      };
    });
  }

  private parseToolCall(
    call: {
      id?: string;
      type?: string;
      function?: { name?: string; arguments?: string };
    },
    index: number,
  ): ToolCall | null {
    const name = call.function?.name;
    if (typeof name !== "string" || !name) return null;

    const rawArgs = call.function?.arguments ?? "{}";
    let parsed: Record<string, unknown> = {};
    try {
      const decoded = JSON.parse(rawArgs);
      if (decoded && typeof decoded === "object" && !Array.isArray(decoded)) {
        parsed = decoded as Record<string, unknown>;
      }
    } catch {
      parsed = { __parseError: rawArgs.slice(0, 200) };
    }

    return {
      id: typeof call.id === "string" && call.id ? call.id : `call_${index}`,
      name,
      arguments: parsed,
    };
  }
}
