import "dotenv/config";

function num(value: string | undefined, fallback: number): number {
  if (value === undefined || value === "") return fallback;
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) {
    throw new Error(`Expected a number, got "${value}".`);
  }
  return parsed;
}

function bool(value: string | undefined, fallback: boolean): boolean {
  if (value === undefined || value === "") return fallback;
  return value.toLowerCase() !== "false";
}

function csv(value: string | undefined): string[] {
  if (!value) return [];
  return value
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean);
}

export const env = {
  nodeEnv: process.env.NODE_ENV ?? "development",
  port: num(process.env.PORT, 4000),
  databaseUrl: process.env.DATABASE_URL ?? "",
  defaultUserId: process.env.DEFAULT_USER_ID ?? "",

  jwtSecret: process.env.JWT_SECRET ?? "",

  aiProvider: process.env.AI_PROVIDER ?? "openai",
  aiApiKey: process.env.AI_API_KEY ?? "",
  aiModel: process.env.AI_MODEL ?? "gpt-4o-mini",
  aiBaseUrl: process.env.AI_BASE_URL ?? "https://api.openai.com/v1",
  aiTimeoutMs: num(process.env.AI_TIMEOUT_MS, 30_000),

  memoryEnabled: bool(process.env.MEMORY_ENABLED, true),
  memoryRetrievalEnabled: bool(process.env.MEMORY_RETRIEVAL_ENABLED, true),
  memoryMaxItems: num(process.env.MEMORY_MAX_ITEMS, 8),
  memoryMinScore: num(process.env.MEMORY_MIN_SCORE, 0.65),
  memoryMaxContextTokens: num(process.env.MEMORY_MAX_CONTEXT_TOKENS, 1500),
  memoryAutoSaveEnabled: bool(process.env.MEMORY_AUTO_SAVE_ENABLED, true),
  memoryConfirmationEnabled: bool(
    process.env.MEMORY_CONFIRMATION_ENABLED,
    true,
  ),

  bodyLimit: process.env.BODY_LIMIT ?? "100kb",
  agentRateLimitPerMinute: num(process.env.AGENT_RATE_LIMIT_PER_MINUTE, 20),
  corsOrigins: csv(process.env.CORS_ORIGINS),
};

// --- Validation -------------------------------------------------------------

if (!env.databaseUrl) {
  throw new Error("DATABASE_URL is required.");
}

if (!["openai", "ollama"].includes(env.aiProvider)) {
  throw new Error("AI_PROVIDER must be openai or ollama.");
}

if (!Number.isInteger(env.port) || env.port <= 0 || env.port > 65535) {
  throw new Error("PORT must be an integer between 1 and 65535.");
}

if (!env.defaultUserId) {
  throw new Error("DEFAULT_USER_ID is required.");
}

if (
  !/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
    env.defaultUserId,
  )
) {
  throw new Error("DEFAULT_USER_ID must be a v4 UUID.");
}

if (!env.jwtSecret || env.jwtSecret.length < 32) {
  throw new Error("JWT_SECRET must be at least 32 characters.");
}

if (env.aiProvider === "openai" && !env.aiApiKey) {
  throw new Error("AI_API_KEY is required when using OpenAI.");
}
// if (!env.corsOrigins.length) {
//   throw new Error("CORS_ORIGINS is required in production.");
// }
