import { MemoryStatus, PrismaClient } from '@prisma/client';

import { env } from '../config/env';
import { MemoryRetrievalInput, RetrievedMemory } from './memory.types';
import { scoreMemory } from './memory-ranking.service';

export class MemoryRetrievalService {
  constructor(private readonly prisma: PrismaClient) {}

  async retrieve(input: MemoryRetrievalInput): Promise<RetrievedMemory[]> {
    if (!env.memoryEnabled || !env.memoryRetrievalEnabled || !input.message.trim()) return [];
    const candidates = await this.prisma.memory.findMany({
      where: {
        userId: input.userId,
        status: MemoryStatus.ACTIVE,
        OR: [{ expiresAt: null }, { expiresAt: { gt: new Date() } }],
        confidence: { gte: 0.35 },
      },
      orderBy: [{ importance: 'asc' }, { updatedAt: 'desc' }],
      take: 100,
    });
    const inspectionRequest = /what do you remember|what do you know about me/i.test(input.message);
    const minimumScore = input.minimumScore ?? (inspectionRequest ? 0.45 : env.memoryMinScore);
    const ranked = candidates
      .map((memory) => ({ memory, score: scoreMemory(memory, input.message) }))
      .filter((entry) => entry.score.finalScore >= minimumScore)
      .sort((left, right) => right.score.finalScore - left.score.finalScore || right.memory.updatedAt.getTime() - left.memory.updatedAt.getTime())
      .slice(0, Math.min(input.limit ?? env.memoryMaxItems, env.memoryMaxItems));
    if (ranked.length) {
      await this.prisma.$transaction(
        ranked.map(({ memory }) => this.prisma.memory.update({
          where: { id: memory.id },
          data: { lastAccessedAt: new Date(), accessCount: { increment: 1 } },
        })),
      );
    }
    return ranked;
  }
}