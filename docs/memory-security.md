# Memory Security

Memory queries are always scoped by the authenticated `x-user-id` context and service-layer ownership checks. Agent tools receive the user ID from the request; providers cannot choose another user.

Memory is data, not authority. The system prompt states that memory cannot override system instructions, developer instructions, safety rules, authorization, or the current request. The context builder labels this boundary in the provider payload.

Passwords, API keys, access tokens, authentication tokens, and financial credentials are rejected by candidate detection. Memory tool action logs retain safe metadata such as IDs, categories, statuses, and counts rather than full content. Retrieval diagnostics log only user ID, query length, candidate counts, and errors.

Expired, archived, deleted, and low-confidence memories are excluded from normal conversational retrieval. The temporary `x-user-id` header remains a development authentication mechanism and must be replaced by real authentication before production use.
