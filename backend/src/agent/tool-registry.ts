import { PrismaClient } from "@prisma/client";

import {
  archiveMemory,
  createMemory,
  deleteMemory,
  getRelevantMemories,
  searchMemories,
  updateMemory,
} from "../memory/memory.service";
import { getAssistantProfile } from "../modules/assistant/assistant.service";
import { listGoals } from "../modules/goals/goals.service";
import { getPreferences } from "../modules/preferences/preferences.service";
import { getProfile } from "../modules/profile/profile.service";
import {
  cancelReminder,
  createReminder,
  updateReminder,
} from "../modules/reminders/reminders.service";
import {
  cancelTask,
  createTask,
  getCompletedTasks,
  getOverdueTasks,
  getPendingTasks,
  getTodayTasks,
  getUpcomingTasks,
  updateTask,
  updateTaskStatus,
} from "../modules/tasks/tasks.service";
import { buildMemoryContext } from "../memory/memory-context.service";
import { resolveMemoryCandidate } from "../memory/memory-detection.service";
import { MemoryRetrievalService } from "../memory/memory-retrieval.service";
import { MemoryCandidate, MemoryContext } from "../memory/memory.types";
import {
  AgentContext,
  ToolCall,
  ToolPermission,
  ToolResult,
} from "./agent.types";

type ToolDefinition = {
  name: string;
  description: string;
  permission: ToolPermission;
  parameters: Record<string, unknown>;
  execute: (userId: string, args: Record<string, unknown>) => Promise<unknown>;
};

const objectParameters = (
  properties: Record<string, unknown>,
  required: string[] = [],
) => ({ type: "object", properties, required });

const stringProp = (description: string) => ({
  type: "string",
  description,
});

const dateTimeProp = (description: string) => ({
  type: "string",
  format: "date-time",
  description,
});

const enumProp = (values: string[], description: string) => ({
  type: "string",
  enum: values,
  description,
});

export class ToolRegistry {
  private readonly tools: Map<string, ToolDefinition>;

  constructor(private readonly prisma: PrismaClient) {
    this.tools = new Map(
      [
        // ---------------------------------------------------------------------
        // READ: context
        // ---------------------------------------------------------------------
        this.read(
          "get_user_profile",
          "Get the user's profile (name, timezone, bio). Use this when the user asks about themselves or when you need personal context to answer well.",
          objectParameters({}),
          (userId) => getProfile(prisma, userId),
        ),
        this.read(
          "get_user_preferences",
          "Get the user's preferences (timezone, formats, notification settings).",
          objectParameters({}),
          (userId) => getPreferences(prisma, userId),
        ),
        this.read(
          "get_assistant_profile",
          "Get the assistant configuration (name, personality).",
          objectParameters({}),
          (userId) => getAssistantProfile(prisma, userId),
        ),

        // ---------------------------------------------------------------------
        // READ: goals
        // ---------------------------------------------------------------------
        this.read(
          "get_goals",
          "Get all of the user's goals. Use this when the user asks about goals, long-term plans, or direction.",
          objectParameters({}),
          (userId) => listGoals(prisma, userId),
        ),

        // ---------------------------------------------------------------------
        // READ: tasks
        // ---------------------------------------------------------------------
        this.read(
          "get_today_tasks",
          'Get tasks due today. Use this when the user asks "what\'s on my plate today", "what do I have today", or similar.',
          objectParameters({}),
          (userId) => getTodayTasks(prisma, userId),
        ),
        this.read(
          "get_pending_tasks",
          'Get all pending tasks across every due date. Use this when the user asks generally about "my tasks", "what do I have to do", or "what should I focus on" without a specific day.',
          objectParameters({}),
          (userId) => getPendingTasks(prisma, userId),
        ),
        this.read(
          "get_overdue_tasks",
          "Get tasks whose due date has passed and are still open. Use this when the user asks about overdue, late, or missed items.",
          objectParameters({}),
          (userId) => getOverdueTasks(prisma, userId),
        ),
        this.read(
          "get_upcoming_tasks",
          "Get tasks due after today. Use this when the user asks about upcoming work or the next few days.",
          objectParameters({}),
          (userId) => getUpcomingTasks(prisma, userId),
        ),
        this.read(
          "get_completed_tasks",
          "Get recently completed tasks. Use this when the user asks what they got done or what has been finished.",
          objectParameters({}),
          (userId) => getCompletedTasks(prisma, userId),
        ),

        // ---------------------------------------------------------------------
        // READ: memory
        // ---------------------------------------------------------------------
        this.read(
          "get_relevant_memory",
          'Look up relevant memories about the user based on a query. Use this when the user asks "what do you remember" or when you need personal context that is not in your prompt already.',
          objectParameters(
            {
              query: stringProp("The query to match memories against."),
              limit: { type: "number", description: "Max memories to return." },
            },
            ["query"],
          ),
          async (userId, args) =>
            getRelevantMemories(
              prisma,
              userId,
              this.requiredString(args, "query"),
              typeof args.limit === "number" ? args.limit : undefined,
            ),
        ),
        this.read(
          "search_memories",
          "Search the user's memories by keyword. Use this when the user references a specific fact or asks to find something they told you before.",
          objectParameters(
            {
              query: stringProp("Search query."),
              limit: { type: "number", description: "Max memories to return." },
            },
            ["query"],
          ),
          (userId, args) =>
            searchMemories(prisma, userId, this.requiredString(args, "query"), {
              limit: typeof args.limit === "number" ? args.limit : undefined,
            }),
        ),

        // ---------------------------------------------------------------------
        // WRITE: memory
        // ---------------------------------------------------------------------
        this.write(
          "save_memory",
          'Save a long-term fact about the user. Use ONLY when the user explicitly asks you to remember something ("remember that...", "keep in mind that..."), or when the fact is clearly stable and personal.',
          objectParameters(
            {
              category: enumProp(
                [
                  "PERSONAL",
                  "GOAL",
                  "PROJECT",
                  "PEOPLE",
                  "PREFERENCE",
                  "DECISION",
                  "IMPORTANT_CONTEXT",
                ],
                "Memory category.",
              ),
              title: stringProp("Short title for the memory."),
              content: stringProp("The memory content."),
              importance: enumProp(
                ["HIGH", "MEDIUM", "LOW"],
                "Memory importance.",
              ),
              source: enumProp(
                ["USER", "AI", "SYSTEM", "IMPORTED"],
                "Where the memory came from.",
              ),
              confidence: {
                type: "number",
                minimum: 0,
                maximum: 1,
                description: "Confidence between 0 and 1.",
              },
              expiresAt: dateTimeProp("Optional expiry for time-bound facts."),
            },
            ["category", "title", "content"],
          ),
          (userId, args) => createMemory(prisma, userId, args),
        ),
        this.write(
          "update_memory",
          "Update an existing memory. The user must reference a specific memory, or you must first search memories to find the matching id.",
          objectParameters(
            {
              memoryId: stringProp("The memory id to update."),
              title: stringProp("New title."),
              content: stringProp("New content."),
              category: stringProp("New category."),
              importance: stringProp("New importance."),
              confidence: { type: "number", minimum: 0, maximum: 1 },
              expiresAt: dateTimeProp("New expiry."),
              status: enumProp(
                ["ACTIVE", "ARCHIVED", "DELETED"],
                "New status.",
              ),
            },
            ["memoryId"],
          ),
          (userId, args) =>
            updateMemory(
              prisma,
              userId,
              this.requiredString(args, "memoryId"),
              args,
            ),
        ),
        this.write(
          "archive_memory",
          'Archive a memory so it stops appearing in retrieval but is kept in history. Use when the user says "forget" or "stop remembering" something.',
          objectParameters({ memoryId: stringProp("The memory id.") }, [
            "memoryId",
          ]),
          (userId, args) =>
            archiveMemory(
              prisma,
              userId,
              this.requiredString(args, "memoryId"),
            ),
        ),
        this.write(
          "delete_memory",
          "Permanently forget a memory (soft delete). Use when the user explicitly asks to remove a fact entirely.",
          objectParameters({ memoryId: stringProp("The memory id.") }, [
            "memoryId",
          ]),
          (userId, args) =>
            deleteMemory(prisma, userId, this.requiredString(args, "memoryId")),
        ),

        // ---------------------------------------------------------------------
        // WRITE: tasks
        // ---------------------------------------------------------------------
        this.write(
          "create_task",
          "Create a new task for the user. Use this whenever the user asks to add, remember, schedule, or create something they need to do.",
          objectParameters(
            {
              title: stringProp("Task title."),
              description: stringProp("Optional task description."),
              priority: enumProp(
                ["URGENT", "HIGH", "MEDIUM", "LOW"],
                "Task priority.",
              ),
              dueDate: dateTimeProp("Optional ISO 8601 due date."),
            },
            ["title"],
          ),
          (userId, args) =>
            createTask(prisma, userId, {
              ...args,
              source: "AI_CONVERSATION",
            }),
        ),
        this.write(
          "update_task",
          "Update a specific existing task (title, description, priority, or status). The user must reference a specific task, or you must first call get_pending_tasks to find the matching task id.",
          objectParameters(
            {
              taskId: stringProp("The task id."),
              title: stringProp("New title."),
              description: stringProp("New description."),
              priority: enumProp(
                ["URGENT", "HIGH", "MEDIUM", "LOW"],
                "New priority.",
              ),
              status: enumProp(
                ["TODO", "IN_PROGRESS", "COMPLETED", "CANCELLED"],
                "New status.",
              ),
            },
            ["taskId"],
          ),
          (userId, args) =>
            updateTask(
              prisma,
              userId,
              this.requiredString(args, "taskId"),
              args,
            ),
        ),
        this.write(
          "complete_task",
          "Mark a specific task as complete. The user must reference a specific task, or you must first call get_pending_tasks to find the matching task id.",
          objectParameters({ taskId: stringProp("The task id.") }, ["taskId"]),
          (userId, args) =>
            updateTaskStatus(
              prisma,
              userId,
              this.requiredString(args, "taskId"),
              "COMPLETED",
            ),
        ),
        this.write(
          "cancel_task",
          "Cancel a specific task. The user must reference a specific task, or you must first call get_pending_tasks to find the matching task id.",
          objectParameters({ taskId: stringProp("The task id.") }, ["taskId"]),
          (userId, args) =>
            cancelTask(prisma, userId, this.requiredString(args, "taskId")),
        ),

        // ---------------------------------------------------------------------
        // WRITE: reminders
        // ---------------------------------------------------------------------
        this.write(
          "create_reminder",
          'Create a reminder at a specific date and time. Use this when the user says "remind me", "nudge me", or "let me know at [time]". remindAt must be ISO 8601.',
          objectParameters(
            {
              title: stringProp("Reminder title."),
              description: stringProp("Optional description."),
              taskId: stringProp("Optional task id to link to."),
              remindAt: dateTimeProp("When to be reminded (ISO 8601)."),
            },
            ["title", "remindAt"],
          ),
          (userId, args) => createReminder(prisma, userId, args),
        ),
        this.write(
          "update_reminder",
          "Update a specific existing reminder. The user must reference a specific reminder, or you must first list reminders.",
          objectParameters(
            {
              reminderId: stringProp("The reminder id."),
              title: stringProp("New title."),
              remindAt: dateTimeProp("New remind-at time (ISO 8601)."),
              taskId: stringProp("New linked task id."),
            },
            ["reminderId"],
          ),
          (userId, args) =>
            updateReminder(
              prisma,
              userId,
              this.requiredString(args, "reminderId"),
              args,
            ),
        ),
        this.write(
          "cancel_reminder",
          "Cancel a specific reminder. The user must reference a specific reminder, or you must first list reminders.",
          objectParameters({ reminderId: stringProp("The reminder id.") }, [
            "reminderId",
          ]),
          (userId, args) =>
            cancelReminder(
              prisma,
              userId,
              this.requiredString(args, "reminderId"),
            ),
        ),
      ].map((tool) => [tool.name, tool]),
    );
  }

  async resolveMemoryCandidate(
    userId: string,
    message: string,
  ): Promise<{ candidate: MemoryCandidate | null; result?: ToolResult }> {
    const candidate = await resolveMemoryCandidate(
      this.prisma,
      userId,
      message,
    );
    if (
      !candidate ||
      !["STORE_AUTOMATICALLY", "UPDATE_EXISTING"].includes(candidate.decision)
    ) {
      return { candidate };
    }

    if (
      candidate.decision === "UPDATE_EXISTING" &&
      candidate.existingMemoryId
    ) {
      const toolCall = {
        name: "update_memory",
        arguments: {
          memoryId: candidate.existingMemoryId,
          category: candidate.category,
          title: candidate.title,
          content: candidate.content,
          importance: candidate.importance,
          confidence: candidate.confidence,
          ...(candidate.expiresAt ? { expiresAt: candidate.expiresAt } : {}),
        },
      };
      return { candidate, result: await this.execute(userId, toolCall) };
    }

    const toolCall = {
      name: "save_memory",
      arguments: {
        category: candidate.category,
        title: candidate.title,
        content: candidate.content,
        importance: candidate.importance,
        source: "AI",
        confidence: candidate.confidence,
        ...(candidate.expiresAt ? { expiresAt: candidate.expiresAt } : {}),
      },
    };
    return { candidate, result: await this.execute(userId, toolCall) };
  }

  definitions() {
    return [...this.tools.values()].map(
      ({ name, description, permission, parameters }) => ({
        name,
        description,
        permission,
        parameters,
      }),
    );
  }

  async execute(userId: string, call: ToolCall): Promise<ToolResult> {
    const tool = this.tools.get(call.name);
    if (!tool) return { toolCall: call, ok: false, output: "Unknown tool." };
    try {
      return {
        toolCall: call,
        ok: true,
        output: await tool.execute(userId, call.arguments),
      };
    } catch (error) {
      return {
        toolCall: call,
        ok: false,
        output:
          error instanceof Error ? error.message : "Tool execution failed.",
      };
    }
  }

  async getContext(userId: string, query = ""): Promise<AgentContext> {
    const [profile, preferences, assistantProfile, goals] = await Promise.all([
      getProfile(this.prisma, userId),
      getPreferences(this.prisma, userId),
      getAssistantProfile(this.prisma, userId),
      listGoals(this.prisma, userId),
    ]);

    let memories: MemoryContext = {
      memories: [],
      formattedContext: "",
      tokenEstimate: 0,
    };
    try {
      const retrieved = await new MemoryRetrievalService(this.prisma).retrieve({
        userId,
        message: query,
      });
      memories = buildMemoryContext(retrieved);
    } catch (error) {
      console.warn(
        "Memory retrieval unavailable; continuing without memory context.",
        {
          userId,
          queryLength: query.length,
          error: error instanceof Error ? error.message : "unknown",
        },
      );
    }

    return { profile, preferences, assistantProfile, goals, memories };
  }

  private read(
    name: string,
    description: string,
    parameters: Record<string, unknown>,
    execute: ToolDefinition["execute"],
  ): ToolDefinition {
    return { name, description, permission: "READ", parameters, execute };
  }

  private write(
    name: string,
    description: string,
    parameters: Record<string, unknown>,
    execute: ToolDefinition["execute"],
  ): ToolDefinition {
    return { name, description, permission: "WRITE", parameters, execute };
  }

  private requiredString(args: Record<string, unknown>, key: string): string {
    const value = args[key];
    if (typeof value !== "string" || !value.trim()) {
      throw new Error(`${key} is required.`);
    }
    return value;
  }
}
