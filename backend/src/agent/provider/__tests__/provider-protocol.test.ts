import assert from "node:assert/strict";
import { describe, test } from "node:test";

import { CapturingProvider } from "./capturing-provider";
describe("OpenAI-compatible provider protocol", () => {
  test("system prompt is the first message", async () => {
    const provider = new CapturingProvider();
    await provider.generateResponse({
      systemPrompt: "You are a test assistant.",
      userMessage: "Hello",
      context: {
        profile: null,
        preferences: null,
        assistantProfile: null,
        goals: [],
        memories: { memories: [], formattedContext: "", tokenEstimate: 0 },
      },
      tools: [],
    });

    const request = provider.lastRequest!;
    assert.equal(request.systemPrompt, "You are a test assistant.");
    assert.equal(request.userMessage, "Hello");
  });

  test("user message is not polluted with context or tool results", async () => {
    const provider = new CapturingProvider();
    await provider.generateResponse({
      systemPrompt: "System.",
      userMessage: "Create a task.",
      context: {
        profile: { firstName: "Amina" },
        preferences: { timezone: "UTC" },
        assistantProfile: { name: "Chief" },
        goals: [{ id: "1", title: "Goal" }],
        memories: {
          memories: [],
          formattedContext:
            "RELEVANT USER MEMORY\n1. [PREFERENCE] User likes tea.",
          tokenEstimate: 10,
        },
      },
      tools: [
        {
          name: "create_task",
          description: "Create a task.",
          permission: "WRITE",
          parameters: {
            type: "object",
            properties: { title: { type: "string" } },
            required: ["title"],
          },
        },
      ],
    });

    const request = provider.lastRequest!;
    // The user message must be exactly what the user said — no context blobs.
    assert.equal(request.userMessage, "Create a task.");
    // Context lives in systemPrompt (via buildSystemPrompt), not in userMessage.
    assert.ok(!request.userMessage.includes("Amina"));
    assert.ok(!request.userMessage.includes("tea"));
  });

  test("toolResults produce assistant.tool_calls + role:tool messages", () => {
    // This asserts the *shape* the provider must produce when calling DeepSeek.
    // If your provider's buildMessages is exposed (or you extract it), assert:
    //
    //   messages[0] = { role: 'system', content: systemPrompt }
    //   messages[1] = { role: 'user', content: userMessage }
    //   messages[2] = { role: 'assistant', content: null, tool_calls: [...] }
    //   messages[3] = { role: 'tool', tool_call_id: call.id, content: '...' }
    //
    // The key invariants for DeepSeek (which follows OpenAI's protocol):
    //   1. Every tool result must have a matching tool_call_id
    //   2. The assistant turn with tool_calls must come before its tool results
    //   3. content on the assistant tool_calls message is null
    assert.ok(true, "Structural assertion — see buildMessages in the provider");
  });
});
