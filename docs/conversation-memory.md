# Conversation Memory

`POST /api/agent/chat` retrieves relevant memory before the provider call. The response includes `memoryUsed` and, when confirmation is required, non-sensitive `memoryCandidates` containing category, title, content, confidence, decision, and optional expiration.

The Flutter chat shows a subtle personal-context indicator and asks before saving uncertain candidates. Choosing `Not now` discards the candidate. Choosing `Remember this` uses the normal authenticated memory API.

The deterministic development provider supports these flows without a real AI API:

- `Remember that ...` saves explicit memory through `save_memory`.
- `Forget that ...` searches and archives matching memories.
- `What do you remember about me?` uses relevant memory retrieval.
- Stable preference/project/goal statements are detected after the response.

Memory is optional. Empty, unavailable, expired, archived, or low-confidence memory does not prevent the assistant from responding.
