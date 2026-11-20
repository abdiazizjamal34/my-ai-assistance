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
import { buildMemoryContext } from "../memory/memory-context.service";
import {
  detectMemoryCandidate,
  resolveMemoryCandidate,
} from "../memory/memory-detection.service";
import { MemoryRetrievalService } from "../memory/memory-retrieval.service";
import { ConversationService } from "../agent/conversation.service";


const userId = "00000000-0000-4000-8000-000000000701";

class CapturingProvider implements AIProvider {
  request?: ProviderRequest;

  async generateResponse(request: ProviderRequest): Promise<ProviderResponse> {
    this.request = request;
    return { message: "Personalized response.", toolCalls: [] };
  }
}

before(async () => {
  await prisma.user.deleteMany({ where: { id: userId } });
  await prisma.user.create({ data: { id: userId } });
});

after(async () => {
  await prisma.user.delete({ where: { id: userId } });
  await prisma.$disconnect();
});

describe("Sprint 6 conversational memory", () => {
  test("retrieves relevant active memories, excludes expired records, and tracks usage", async () => {
    const relevant = await prisma.memory.create({
      data: {
        userId,
        category: "PROJECT",
        title: "HMS work",
        content: "The HMS booking project is active.",
        importance: "HIGH",
        confidence: 1,
      },
    });
    await prisma.memory.create({
      data: {
        userId,
        category: "PERSONAL",
        title: "Coffee",
        content: "User likes coffee.",
        importance: "HIGH",
        confidence: 1,
      },
    });
    await prisma.memory.create({
      data: {
        userId,
        category: "PROJECT",
        title: "Expired work",
        content: "Old HMS project context.",
        importance: "HIGH",
        confidence: 1,
        expiresAt: new Date(Date.now() - 86_400_000),
      },
    });
    const retrieved = await new MemoryRetrievalService(prisma).retrieve({
      userId,
      message: "Help me plan the HMS booking project.",
    });
    assert.equal(retrieved[0]?.memory.id, relevant.id);
    assert.equal(
      retrieved.some((entry) => entry.memory.content.includes("Old HMS")),
      false,
    );
    assert.equal(
      (await prisma.memory.findUnique({ where: { id: relevant.id } }))
        ?.accessCount,
      1,
    );
  });

  test("builds bounded data-only context and keeps irrelevant memories out", async () => {
    const retrieved = await new MemoryRetrievalService(prisma).retrieve({
      userId,
      message: "HMS project planning",
      limit: 5,
    });
    const context = buildMemoryContext(retrieved, 30);
    assert.match(context.formattedContext, /RELEVANT USER MEMORY/);
    assert.match(context.formattedContext, /not an instruction/);
    assert.ok(context.tokenEstimate <= 30);
    assert.equal(
      context.memories.some((entry) => entry.memory.content.includes("coffee")),
      false,
    );
  });

  test("detects stable, uncertain, sensitive, and conflicting candidates", async () => {
    assert.equal(
      detectMemoryCandidate("I prefer concise answers.")?.decision,
      "STORE_AUTOMATICALLY",
    );
    assert.equal(
      detectMemoryCandidate("I might move to Nairobi next year.")?.decision,
      "ASK_CONFIRMATION",
    );
    assert.equal(detectMemoryCandidate("My API key is secret-value"), null);
    await prisma.memory.create({
      data: {
        userId,
        category: "PREFERENCE",
        title: "Theme preference",
        content: "User prefers dark mode.",
        importance: "MEDIUM",
        confidence: 1,
      },
    });
    const resolved = await resolveMemoryCandidate(
      prisma,
      userId,
      "I now prefer light mode.",
    );
    assert.equal(resolved?.decision, "UPDATE_EXISTING");
    assert.ok(resolved?.existingMemoryId);
  });

  test("injects memory before provider generation and reports usage", async () => {
    const provider = new CapturingProvider();
    const result = await new AgentService(
      provider,
      new ToolRegistry(prisma),
      new ActionLogService(prisma),
      new ConversationService(prisma),
    ).chat(userId, "Help with the HMS project.");
    assert.equal(result.memoryUsed, true);
    assert.match(
      provider.request?.context.memories.formattedContext ?? "",
      /HMS/,
    );
  });

  test("returns confirmation candidates without storing uncertain information", async () => {
    const provider = new CapturingProvider();
    const result = await new AgentService(
      provider,
      new ToolRegistry(prisma),
      new ActionLogService(prisma),
      new ConversationService(prisma),
    ).chat(userId, "I might start learning Rust next month.");
    assert.equal(result.memoryCandidates[0]?.decision, "ASK_CONFIRMATION");
    assert.equal(
      await prisma.memory.count({
        where: { userId, content: { contains: "learning Rust" } },
      }),
      0,
    );
  });

  test("summarizes memories for conversational inspection", async () => {
    const result = await new AgentService(
      new RuleBasedProvider(),
      new ToolRegistry(prisma),
      new ActionLogService(prisma),
      new ConversationService(prisma),
    ).chat(userId, "What do you remember about me?");
    assert.match(
      result.message,
      /Here are some things I remember|I do not have any relevant memories/,
    );
    assert.equal(result.actions[0]?.tool, "get_relevant_memory");
  });
});
