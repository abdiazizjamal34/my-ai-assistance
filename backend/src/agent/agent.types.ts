import { MemoryContext } from '../memory/memory.types';

export type ToolPermission = 'READ' | 'WRITE';

export type ToolCall = {
  id?: string;
  name: string;
  arguments: Record<string, unknown>;
};

export type ToolResult = {
  toolCall: ToolCall;
  ok: boolean;
  output: unknown;
};

export type AgentContext = {
  profile: unknown;
  preferences: unknown;
  assistantProfile: unknown;
  goals: unknown;
  memories: MemoryContext;
};

export type HistoryTurn = {
  role: "user" | "assistant";
  content: string;
};

export type ProviderRequest = {
  systemPrompt: string;
  userMessage: string;
  context: AgentContext;
  tools: Array<{ name: string; description: string; permission: ToolPermission; parameters: Record<string, unknown> }>;
  toolResults?: ToolResult[];
  /** Previous turns in this conversation, oldest → newest, excluding the current message. */
  history?: HistoryTurn[];
};

export type ProviderResponse = {
  message: string;
  toolCalls: ToolCall[];
};

export interface AIProvider {
  generateResponse(request: ProviderRequest): Promise<ProviderResponse>;
}


export type ProviderStreamChunk =
  | { type: 'text'; delta: string }
  | { type: 'done'; message: string }
  | { type: 'error'; message: string };

export interface AIProvider {
  generateResponse(request: ProviderRequest): Promise<ProviderResponse>;
  streamResponse?(request: ProviderRequest): AsyncIterable<ProviderStreamChunk>;
}

