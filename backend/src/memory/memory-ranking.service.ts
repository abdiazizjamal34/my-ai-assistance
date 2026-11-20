import { MemoryCategory, MemoryImportance } from '@prisma/client';

import { MemoryScoreBreakdown } from './memory.types';

const importanceWeights: Record<MemoryImportance, number> = { HIGH: 1, MEDIUM: 0.65, LOW: 0.35 };
const typeWeights: Record<MemoryCategory, number> = {
  PERSONAL: 0.7,
  GOAL: 0.9,
  PROJECT: 1,
  PEOPLE: 0.65,
  PREFERENCE: 0.9,
  DECISION: 0.8,
  IMPORTANT_CONTEXT: 0.85,
};

export function memoryTokens(value: string): string[] {
  return [...new Set(value.toLowerCase().match(/[a-z0-9]+/g) ?? [])].filter((token) => token.length > 2);
}

export function scoreMemory(memory: {
  title: string;
  content: string;
  category: MemoryCategory;
  importance: MemoryImportance;
  confidence: number;
  updatedAt: Date;
  accessCount: number;
}, query: string): MemoryScoreBreakdown {
  const queryTokens = memoryTokens(query);
  const searchable = memoryTokens(`${memory.title} ${memory.content}`);
  const overlap = queryTokens.filter((token) => searchable.includes(token)).length;
  const semanticScore = queryTokens.length ? Math.min(1, overlap / queryTokens.length) : 0;
  const ageDays = Math.max(0, (Date.now() - memory.updatedAt.getTime()) / 86_400_000);
  const recencyScore = Math.max(0, 1 - ageDays / 365);
  const usageScore = Math.min(1, Math.log1p(memory.accessCount) / Math.log(11));
  const importanceScore = importanceWeights[memory.importance];
  const confidenceScore = Math.max(0, Math.min(1, memory.confidence));
  const typePriority = typeWeights[memory.category];
  const finalScore = semanticScore * 0.4 + importanceScore * 0.2 + confidenceScore * 0.15 + recencyScore * 0.1 + usageScore * 0.05 + typePriority * 0.1;
  const reason = semanticScore >= 0.5
    ? 'Matches the current conversation strongly.'
    : 'Included because its importance and confidence support the current context.';
  return { semanticScore, importanceScore, confidenceScore, recencyScore, usageScore, typePriority, finalScore, reason };
}