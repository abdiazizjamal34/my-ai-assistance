import { Memory, MemoryCategory, MemoryImportance, MemorySource, MemoryStatus } from '@prisma/client';

export type MemoryFilters = {
  category?: MemoryCategory;
  importance?: MemoryImportance;
  status?: MemoryStatus;
};

export type RelevantMemoryOptions = MemoryFilters & {
  limit?: number;
};

export type MemoryRetrievalInput = {
  userId: string;
  conversationId?: string;
  message: string;
  limit?: number;
  minimumScore?: number;
};

export type MemoryScoreBreakdown = {
  semanticScore: number;
  importanceScore: number;
  confidenceScore: number;
  recencyScore: number;
  usageScore: number;
  typePriority: number;
  finalScore: number;
  reason: string;
};

export type RetrievedMemory = {
  memory: Memory;
  score: MemoryScoreBreakdown;
};

export type MemoryContext = {
  memories: RetrievedMemory[];
  formattedContext: string;
  tokenEstimate: number;
};

export type MemoryCandidateDecision = 'IGNORE' | 'STORE_AUTOMATICALLY' | 'ASK_CONFIRMATION' | 'UPDATE_EXISTING';

export type MemoryCandidate = {
  decision: MemoryCandidateDecision;
  category: MemoryCategory;
  title: string;
  content: string;
  importance: MemoryImportance;
  confidence: number;
  expiresAt?: string;
  existingMemoryId?: string;
};
