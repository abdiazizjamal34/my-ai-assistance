import "dotenv/config";

import cors from "cors";
import express from "express";
import helmet from "helmet";
// import rateLimit from 'express-rate-limit';

import rateLimit, { ipKeyGenerator } from "express-rate-limit";
import { authRouter } from "./modules/auth/auth.routes";

import { AgentService } from "./agent/agent.service";
import { createAgentRouter } from "./agent/agent.routes";
import { ActionLogService } from "./agent/action-log.service";
import { ConversationService } from "./agent/conversation.service";
import { OpenAICompatibleProvider } from "./agent/provider/openai-compatible-provider";
import { RuleBasedProvider } from "./agent/provider/rule-based-provider";
import { ToolRegistry } from "./agent/tool-registry";
import { prisma } from "./config/database";
import { env } from "./config/env";
import { errorHandler } from "./middleware/error-handler";
import { requireUserContext } from "./middleware/user-context";
import { memoryRouter } from "./memory/memory.routes";
import { assistantRouter } from "./modules/assistant/assistant.routes";
import { goalsRouter } from "./modules/goals/goals.routes";
import { preferencesRouter } from "./modules/preferences/preferences.routes";
import { profileRouter } from "./modules/profile/profile.routes";
import { remindersRouter } from "./modules/reminders/reminders.routes";
import { tasksRouter } from "./modules/tasks/tasks.routes";
import { healthRouter } from "./routes/health";
import { createConversationRouter } from "./agent/conversation.routes";
import { dashboardRouter } from "./modules/profile/dashboard.routes";

const app = express();

app.set("trust proxy", 1);

// --- Security & parsing -----------------------------------------------------

app.use(helmet());

app.use(
  cors({
    origin: env.corsOrigins.length ? env.corsOrigins : true,
    credentials: false,
  }),
);

app.use(express.json({ limit: env.bodyLimit }));

// --- Rate limiting ----------------------------------------------------------

const globalLimiter = rateLimit({
  windowMs: 60_000,
  limit: 120,
  standardHeaders: "draft-7",
  legacyHeaders: false,
  message: {
    error: "Too many requests. Please slow down.",
    code: "RATE_LIMITED",
  },
});

// const agentLimiter = rateLimit({
//   windowMs: 60_000,
//   limit: env.agentRateLimitPerMinute,
//   standardHeaders: 'draft-7',
//   legacyHeaders: false,
//   keyGenerator: (req) =>
//     (req as unknown as { userId?: string }).userId ?? req.ip ?? 'anonymous',
//   message: {
//     error: 'Too many assistant requests. Please wait a moment.',
//     code: 'RATE_LIMITED',
//   },
// });

const agentLimiter = rateLimit({
  windowMs: 60_000,
  limit: env.agentRateLimitPerMinute,
  standardHeaders: "draft-7",
  legacyHeaders: false,
  keyGenerator: (req) => {
    const userId = (req as unknown as { userId?: string }).userId;
    if (userId) return `user:${userId}`;
    // Fallback to IP — use ipKeyGenerator to normalize IPv6 to /64.
    return ipKeyGenerator(req.ip ?? "anonymous");
  },
  message: {
    error: "Too many assistant requests. Please wait a moment.",
    code: "RATE_LIMITED",
  },
});

const writeLimiter = rateLimit({
  windowMs: 60_000,
  limit: 60,
  standardHeaders: "draft-7",
  legacyHeaders: false,
  skip: (req) => req.method === "GET" || req.method === "HEAD",
  message: { error: "Too many write requests.", code: "RATE_LIMITED" },
});

app.use(globalLimiter);

// --- Health -----------------------------------------------------------------

app.use("/health", healthRouter);

// --- Authenticated API ------------------------------------------------------
app.use("/api/auth", authRouter); // ⬅️ public, no auth required
app.use("/api", requireUserContext);

app.use("/api/profile", profileRouter);
app.use("/api/dashboard", dashboardRouter);
app.use("/api/preferences", preferencesRouter);
app.use("/api/assistant-profile", assistantRouter);
app.use("/api/goals", writeLimiter, goalsRouter);
app.use("/api/tasks", writeLimiter, tasksRouter);
app.use("/api/reminders", writeLimiter, remindersRouter);
app.use("/api/memories", writeLimiter, memoryRouter);

// --- Agent ------------------------------------------------------------------

const provider =
  env.aiProvider === "ollama"
    ? new OpenAICompatibleProvider()
    : env.aiApiKey
      ? new OpenAICompatibleProvider()
      : new RuleBasedProvider();

const conversations = new ConversationService(prisma);

const agent = new AgentService(
  provider,
  new ToolRegistry(prisma),
  new ActionLogService(prisma),
  conversations,
);

app.use("/api/agent", agentLimiter, createAgentRouter(agent));
app.use(
  "/api/conversations",
  writeLimiter,
  createConversationRouter(conversations),
);

// --- 404 --------------------------------------------------------------------

app.use((_req, res) => {
  res.status(404).json({ error: "Not found.", code: "NOT_FOUND" });
});

// --- Error handler ----------------------------------------------------------

app.use(errorHandler);

// --- Lifecycle --------------------------------------------------------------

const server = app.listen(env.port, () => {
  console.log(
    JSON.stringify({
      level: "info",
      msg: "Personal AI backend listening",
      port: env.port,
      nodeEnv: env.nodeEnv,
      provider:
        env.aiProvider === "ollama"
          ? "ollama"
          : env.aiApiKey
            ? "openai-compatible"
            : "rule-based",
    }),
  );
});

async function shutdown(signal: string) {
  console.log(JSON.stringify({ level: "info", msg: "shutting down", signal }));
  server.close(async () => {
    await prisma.$disconnect();
    process.exit(0);
  });
  setTimeout(() => process.exit(1), 10_000).unref();
}

process.on("SIGTERM", () => void shutdown("SIGTERM"));
process.on("SIGINT", () => void shutdown("SIGINT"));

export { app };
