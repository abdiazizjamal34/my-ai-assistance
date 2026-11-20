import "dotenv/config";

import assert from "node:assert/strict";
import { after, before, describe, test } from "node:test";

import { AgentService } from "../agent/agent.service";
import { ActionLogService } from "../agent/action-log.service";
import { ConversationService } from "../agent/conversation.service";
import {
  AIProvider,
  ProviderRequest,
  ProviderResponse,
} from "../agent/agent.types";
import { ToolRegistry } from "../agent/tool-registry";
import { prisma } from "../config/database";
import { createTask } from "./tasks/tasks.service";

const userId = "00000000-0000-4000-8000-000000000501";
const otherUserId = "00000000-0000-4000-8000-000000000502";

class MockProvider implements AIProvider {
  constructor(
    private readonly responses: ProviderResponse[],
    private readonly failure?: Error,
  ) {}

  async generateResponse(_request: ProviderRequest): Promise<ProviderResponse> {
    if (this.failure) throw this.failure;

    const response = this.responses.shift();

    if (!response) {
      throw new Error("Mock response exhausted.");
    }

    return response;
  }
}

function agent(provider: AIProvider) {
  return new AgentService(
    provider,
    new ToolRegistry(prisma),
    new ActionLogService(prisma),
    new ConversationService(prisma),
  );
}

before(async () => {
  await prisma.user.deleteMany({
    where: {
      id: { in: [userId, otherUserId] },
    },
  });

  await prisma.user.createMany({
    data: [{ id: userId }, { id: otherUserId }],
  });
});

after(async () => {
  await prisma.user.deleteMany({
    where: {
      id: { in: [userId, otherUserId] },
    },
  });

  await prisma.$disconnect();
});

describe("Sprint 4 agent core", () => {
  test("receives a message without a tool call", async () => {
    const result = await agent(
      new MockProvider([
        {
          message: "Hello from the Chief.",
          toolCalls: [],
        },
      ]),
    ).chat(userId, "Hello");

    assert.equal(result.message, "Hello from the Chief.");
  });

  test("retrieves profile through a controlled tool", async () => {
    const result = await agent(
      new MockProvider([
        {
          message: "",
          toolCalls: [
            {
              name: "get_user_profile",
              arguments: {},
            },
          ],
        },
        {
          message: "I know your profile context.",
          toolCalls: [],
        },
      ]),
    ).chat(userId, "What do you know about me?");

    assert.equal(result.message, "I know your profile context.");
    assert.equal(result.actions[0]?.tool, "get_user_profile");
  });

  test("creates a task through the task service", async () => {
    const result = await agent(
      new MockProvider([
        {
          message: "",
          toolCalls: [
            {
              name: "create_task",
              arguments: {
                title: "Review agent design",
              },
            },
          ],
        },
        {
          message: "Done. Review agent design is now updated.",
          toolCalls: [],
        },
      ]),
    ).chat(userId, "Create a task");

    assert.equal(result.actions[0]?.success, true);

    const task = await prisma.task.findFirst({
      where: {
        userId,
        title: "Review agent design",
      },
    });

    assert.ok(task);
  });

  test("completes a task through a controlled tool", async () => {
    const task = await createTask(prisma, userId, {
      title: "Complete me",
    });

    const result = await agent(
      new MockProvider([
        {
          message: "",
          toolCalls: [
            {
              name: "complete_task",
              arguments: { taskId: task.id },
            },
          ],
        },
        {
          message: "Done. Complete me is now updated.",
          toolCalls: [],
        },
      ]),
    ).chat(userId, "Complete the task");

    assert.equal(result.actions[0]?.success, true);

    assert.equal(
      (
        await prisma.task.findUnique({
          where: { id: task.id },
        })
      )?.status,
      "COMPLETED",
    );
  });

  test("creates a reminder through a controlled tool", async () => {
    const result = await agent(
      new MockProvider([
        {
          message: "",
          toolCalls: [
            {
              name: "create_reminder",
              arguments: {
                title: "Review reminder",
                remindAt: new Date(Date.now() + 3600000).toISOString(),
              },
            },
          ],
        },
        {
          message: "Done. Review reminder is now updated.",
          toolCalls: [],
        },
      ]),
    ).chat(userId, "Create a reminder");

    assert.equal(result.actions[0]?.success, true);
  });

  test("rejects unknown tools and logs the rejection", async () => {
    const result = await agent(
      new MockProvider([
        {
          message: "",
          toolCalls: [
            {
              name: "delete_database",
              arguments: {},
            },
          ],
        },
        {
          message: "I could not complete that action right now.",
          toolCalls: [],
        },
      ]),
    ).chat(userId, "Do something unsafe");

    assert.equal(result.actions[0]?.success, false);

    const action = await prisma.agentAction.findFirst({
      where: {
        userId,
        toolName: "delete_database",
      },
      orderBy: {
        createdAt: "desc",
      },
    });

    assert.equal(action?.status, "REJECTED");
  });

  test("handles invalid arguments and user isolation", async () => {
    const otherTask = await createTask(prisma, otherUserId, {
      title: "Private task",
    });

    const result = await agent(
      new MockProvider([
        {
          message: "",
          toolCalls: [
            {
              name: "complete_task",
              arguments: { taskId: otherTask.id },
            },
          ],
        },
        {
          message: "I could not complete that action right now.",
          toolCalls: [],
        },
      ]),
    ).chat(userId, "Complete that task");

    assert.equal(result.actions[0]?.success, false);
  });

  test("handles provider failure without exposing internals", async () => {
    await assert.rejects(
      () =>
        agent(new MockProvider([], new Error("provider secret"))).chat(
          userId,
          "Hello",
        ),
      /could not reach the assistant provider/,
    );

    const action = await prisma.agentAction.findFirst({
      where: {
        userId,
        actionType: "AGENT_REQUEST",
        status: "FAILED",
      },
      orderBy: {
        createdAt: "desc",
      },
    });

    assert.ok(action);
  });

  test("rejects empty messages", async () => {
    await assert.rejects(
      () => agent(new MockProvider([])).chat(userId, "   "),
      /message is required/,
    );
  });
});
