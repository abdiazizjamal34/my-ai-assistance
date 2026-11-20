import { MemoryCategory, MemoryImportance, PrismaClient } from '@prisma/client';

import { env } from '../config/env';
import { findSimilarMemory, listMemories } from './memory.service';
import { MemoryCandidate } from './memory.types';

const sensitivePattern = /(?:password|passcode|api key|secret key|access token|authentication token|credit card|bank account)/i;

function candidateForMessage(message: string): MemoryCandidate | null {
  const text = message.trim();
  const lower = text.toLowerCase();
  if (!text || sensitivePattern.test(text) || lower.includes('forget')) return null;

  const preference = /(?:i (?:now )?prefer|i like|my preference is|from now on,?)/i.test(text);
  const uncertain = /(?:i might|maybe i will|i think i may|possibly)/i.test(text);
  const project = /(?:i(?:'m| am) currently working on|working on .* project|my project is)/i.test(text);
  const goal = /(?:my (?:long[- ]term )?goal is|i want to|i plan to)/i.test(text) || (uncertain && /(?:move|learn|start|build|work)/i.test(text));
  if (!preference && !project && !goal) return null;

  const category = preference ? MemoryCategory.PREFERENCE : project ? MemoryCategory.PROJECT : MemoryCategory.GOAL;
  const title = preference ? 'Communication preference' : project ? 'Current project context' : 'Personal goal';
  const confidence = uncertain ? 0.65 : 0.9;
  const expiresAt = uncertain ? new Date(Date.now() + 30 * 86_400_000).toISOString() : undefined;
  return {
    decision: uncertain ? 'ASK_CONFIRMATION' : 'STORE_AUTOMATICALLY',
    category,
    title,
    content: text,
    importance: preference ? MemoryImportance.MEDIUM : MemoryImportance.HIGH,
    confidence,
    ...(expiresAt ? { expiresAt } : {}),
  };
}

export async function resolveMemoryCandidate(
  prisma: PrismaClient,
  userId: string,
  message: string,
): Promise<MemoryCandidate | null> {
  const candidate = candidateForMessage(message);
  if (!candidate) return null;
  if (candidate.decision === 'ASK_CONFIRMATION' || !env.memoryAutoSaveEnabled) return candidate;

  const similar = await findSimilarMemory(prisma, userId, candidate.title, candidate.content, candidate.category);
  if (similar) return { ...candidate, decision: 'UPDATE_EXISTING', existingMemoryId: similar.id };

  if (candidate.category === MemoryCategory.PREFERENCE) {
    const preferences = await listMemories(prisma, userId, { category: MemoryCategory.PREFERENCE, status: 'ACTIVE' });
    const opposite = preferences.find((memory) => {
      const oldText = memory.content.toLowerCase();
      const newText = candidate.content.toLowerCase();
      return (oldText.includes('dark') && newText.includes('light')) || (oldText.includes('light') && newText.includes('dark'));
    });
    if (opposite) return { ...candidate, decision: 'UPDATE_EXISTING', existingMemoryId: opposite.id };
  }
  return candidate;
}

export function detectMemoryCandidate(message: string): MemoryCandidate | null {
  return candidateForMessage(message);
}
