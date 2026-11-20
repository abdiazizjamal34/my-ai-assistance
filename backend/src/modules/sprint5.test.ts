import "dotenv/config";

import assert from "node:assert/strict";
import { after, before, describe, test } from "node:test";

import { AgentService } from "../agent/agent.service";
import { ActionLogService } from "../agent/action-log.service";
import {
  AIProvider,
  ProviderRequest,
  ProviderResponse,
} from "../agent/agent.types";
import { ToolRegistry } from "../agent/tool-registry";
import { RuleBasedProvider } from "../agent/provider/rule-based-provider";
import { prisma } from "../config/database";
import {
  archiveMemory,
  createMemory,
  deleteMemory,
  findSimilarMemory,
  getMemory,
  getRelevantMemories,
  listMemories,
  searchMemories,
  updateMemory,
} from "../memory/memory.service";

import { ConversationService } from "../agent/conversation.service";
const userId = "00000000-0000-4000-8000-000000000601";
const otherUserId = "00000000-0000-4000-8000-000000000602";

class MockProvider implements AIProvider {
  constructor(private readonly responses: ProviderResponse[]) {}

  async generateResponse(_request: ProviderRequest): Promise<ProviderResponse> {
    const response = this.responses.shift();
    if (!response) throw new Error("Mock response exhausted.");
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
    where: { id: { in: [userId, otherUserId] } },
  });
  await prisma.user.createMany({ data: [{ id: userId }, { id: otherUserId }] });
});

after(async () => {
  await prisma.user.deleteMany({
    where: { id: { in: [userId, otherUserId] } },
  });
  await prisma.$disconnect();
});

describe("Sprint 5 personal memory", () => {
  test("creates, reads, lists, updates, archives, and soft deletes memories", async () => {
    const memory = await createMemory(prisma, userId, {
      category: "PREFERENCE",
      title: "Communication style",
      content: "User prefers concise technical explanations.",
      importance: "MEDIUM",
      source: "USER",
      confidence: 1,
      expiresAt: "2027-01-01T00:00:00.000Z",
    });
    assert.equal(
      (await getMemory(prisma, userId, memory.id)).title,
      "Communication style",
    );
    assert.ok(
      (await listMemories(prisma, userId)).some(
        (item) => item.id === memory.id,
      ),
    );
    const updated = await updateMemory(prisma, userId, memory.id, {
      content: "User prefers concise and practical explanations.",
    });
    assert.match(updated.content, /practical/);
    assert.equal(
      (await archiveMemory(prisma, userId, memory.id)).status,
      "ARCHIVED",
    );
    assert.equal(
      (await deleteMemory(prisma, userId, memory.id)).status,
      "DELETED",
    );
  });

  test("searches, ranks relevant memories, and detects duplicates", async () => {
    const preference = await createMemory(prisma, userId, {
      category: "PREFERENCE",
      title: "Answer preference",
      content: "Concise practical answers are useful.",
      importance: "HIGH",
      source: "USER",
      confidence: 1,
    });
    const project = await createMemory(prisma, userId, {
      category: "PROJECT",
      title: "Current project",
      content: "The HMS deployment is a current priority.",
      importance: "MEDIUM",
      source: "USER",
      confidence: 1,
    });
    assert.equal(
      (await searchMemories(prisma, userId, "concise practical")).some(
        (item) => item.id === preference.id,
      ),
      true,
    );
    const relevant = await getRelevantMemories(
      prisma,
      userId,
      "What should I focus on for my project?",
    );
    assert.equal(relevant[0]?.id, project.id);
    assert.equal(
      (
        await findSimilarMemory(
          prisma,
          userId,
          preference.title,
          "Concise practical answers are useful.",
          "PREFERENCE",
        )
      )?.id,
      preference.id,
    );
  });

  test("enforces ownership and input validation", async () => {
    const memory = await createMemory(prisma, userId, {
      category: "PERSONAL",
      title: "Private fact",
      content: "Only my user can access this.",
      importance: "LOW",
      source: "USER",
      confidence: 1,
    });
    await assert.rejects(
      () => getMemory(prisma, otherUserId, memory.id),
      /Memory not found/,
    );
    await assert.rejects(
      () =>
        updateMemory(prisma, otherUserId, memory.id, { title: "No access" }),
      /Memory not found/,
    );
    await assert.rejects(
      () =>
        createMemory(prisma, userId, {
          category: "INVALID",
          title: "Bad",
          content: "Bad",
          importance: "LOW",
          source: "USER",
          confidence: 1,
        }),
      /invalid value/,
    );
    await assert.rejects(
      () =>
        createMemory(prisma, userId, {
          category: "PERSONAL",
          title: "Bad",
          content: "Bad",
          importance: "LOW",
          source: "USER",
          confidence: 2,
        }),
      /between 0 and 1/,
    );
  });

  test("saves explicit remember requests and archives explicit forget requests", async () => {
    const rememberResult = await agent(new RuleBasedProvider()).chat(
      userId,
      "Remember that I prefer concise answers.",
    );
    assert.equal(rememberResult.actions[0]?.tool, "save_memory");
    const saved = await prisma.memory.findFirst({
      where: { userId, content: { contains: "I prefer concise answers" } },
    });
    assert.ok(saved);

    const forgetResult = await agent(new RuleBasedProvider()).chat(
      userId,
      "Forget that I prefer concise answers.",
    );
    assert.equal(
      forgetResult.actions.some((action) => action.tool === "archive_memory"),
      true,
    );
    assert.equal(
      (await prisma.memory.findUnique({ where: { id: saved.id } }))?.status,
      "ARCHIVED",
    );
  });

  test("injects relevant memory and rejects unknown tools", async () => {
    await createMemory(prisma, userId, {
      category: "GOAL",
      title: "Long term goal",
      content: "Build a larger technology company.",
      importance: "HIGH",
      source: "USER",
      confidence: 1,
    });
    const provider = new MockProvider([
      { message: "Context used.", toolCalls: [] },
    ]);
    const result = await agent(provider).chat(
      userId,
      "What is my long term goal?",
    );
    assert.equal(result.message, "Context used.");
    const registry = new ToolRegistry(prisma);
    assert.equal(
      (
        await registry.execute(userId, {
          name: "unknown_memory_tool",
          arguments: {},
        })
      ).ok,
      false,
    );
  });
});
