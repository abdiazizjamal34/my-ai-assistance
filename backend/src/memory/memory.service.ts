import {
  MemoryCategory,
  MemoryImportance,
  MemorySource,
  MemoryStatus,
  Prisma,
  PrismaClient,
} from '@prisma/client';

import { HttpError } from '../middleware/error-handler';
import { parseMemoryFilters, parseMemoryInput } from './memory.validation';
import { MemoryFilters, RelevantMemoryOptions } from './memory.types';

const defaultLimit = 8;
const maxLimit = 10;
const memoryCategories = Object.values(MemoryCategory) as string[];

function activeWhere(userId: string) {
  return {
    userId,
    status: MemoryStatus.ACTIVE,
    OR: [{ expiresAt: null }, { expiresAt: { gt: new Date() } }],
  } satisfies Prisma.MemoryWhereInput;
}

function tokens(value: string): string[] {
  return [...new Set(value.toLowerCase().match(/[a-z0-9]+/g) ?? [])].filter((token) => token.length > 2);
}

function clampLimit(value: number | undefined): number {
  if (value === undefined) return defaultLimit;
  if (!Number.isInteger(value) || value < 1) throw new HttpError(400, 'limit must be a positive integer.');
  return Math.min(value, maxLimit);
}

export async function createMemory(prisma: PrismaClient, userId: string, body: unknown) {
  const input = parseMemoryInput(body);
  if (!input.category || !input.importance || !input.source || !input.title || !input.content) {
    throw new HttpError(400, 'category, importance, source, title, and content are required.');
  }
  const duplicate = await findSimilarMemory(prisma, userId, input.title, input.content, input.category);
  if (duplicate) return duplicate;
  return prisma.memory.create({
    data: {
      userId,
      title: input.title,
      content: input.content,
      category: input.category,
      importance: input.importance,
      source: input.source,
      confidence: input.confidence ?? 1,
      ...(input.expiresAt === undefined ? {} : { expiresAt: input.expiresAt }),
      ...(input.sourceConversationId === undefined ? {} : { sourceConversationId: input.sourceConversationId }),
      ...(input.metadata === undefined ? {} : { metadata: input.metadata as Prisma.InputJsonValue }),
    },
  });
}

export async function getMemory(prisma: PrismaClient, userId: string, memoryId: string) {
  const memory = await prisma.memory.findFirst({ where: { id: memoryId, userId } });
  if (!memory) throw new HttpError(404, 'Memory not found.');
  return memory;
}

export async function listMemories(prisma: PrismaClient, userId: string, query: Record<string, unknown> = {}) {
  const filters = parseMemoryFilters(query);
  return prisma.memory.findMany({
    where: { userId, ...filters },
    orderBy: [{ status: 'asc' }, { updatedAt: 'desc' }],
  });
}

export async function updateMemory(prisma: PrismaClient, userId: string, memoryId: string, body: unknown) {
  await getMemory(prisma, userId, memoryId);
  const input = parseMemoryInput(body, true);
  const data = Object.fromEntries(Object.entries(input).filter(([, value]) => value !== undefined)) as Prisma.MemoryUpdateInput;
  return prisma.memory.update({ where: { id: memoryId }, data });
}

export async function archiveMemory(prisma: PrismaClient, userId: string, memoryId: string) {
  await getMemory(prisma, userId, memoryId);
  return prisma.memory.update({ where: { id: memoryId }, data: { status: MemoryStatus.ARCHIVED } });
}

export async function deleteMemory(prisma: PrismaClient, userId: string, memoryId: string) {
  await getMemory(prisma, userId, memoryId);
  return prisma.memory.update({ where: { id: memoryId }, data: { status: MemoryStatus.DELETED } });
}

export async function searchMemories(
  prisma: PrismaClient,
  userId: string,
  query: string,
  options: RelevantMemoryOptions = {},
) {
  const text = query.trim();
  if (!text) throw new HttpError(400, 'q is required.');
  const parsedFilters = parseMemoryFilters(options as Record<string, unknown>);
  const filters = {
    status: options.status ?? MemoryStatus.ACTIVE,
    ...(parsedFilters.category === undefined ? {} : { category: parsedFilters.category }),
    ...(parsedFilters.importance === undefined ? {} : { importance: parsedFilters.importance }),
  };
  const words = tokens(text);
  const categoryMatches = words.filter((word) => memoryCategories.includes(word.toUpperCase()));
  const where: Prisma.MemoryWhereInput = {
    userId,
    ...filters,
    OR: words.flatMap((word) => [
      { title: { contains: word, mode: 'insensitive' as const } },
      { content: { contains: word, mode: 'insensitive' as const } },
      ...(categoryMatches.includes(word) ? [{ category: { equals: word.toUpperCase() as MemoryCategory } }] : []),
    ]),
  };
  return prisma.memory.findMany({ where, orderBy: [{ importance: 'asc' }, { updatedAt: 'desc' }], take: clampLimit(options.limit) });
}

export async function getRelevantMemories(
  prisma: PrismaClient,
  userId: string,
  query: string,
  limit?: number,
) {
  const text = query.trim();
  if (!text) return [];
  const words = tokens(text);
  const candidates = await prisma.memory.findMany({ where: activeWhere(userId), take: 100 });
  const now = Date.now();
  const importanceScore: Record<MemoryImportance, number> = { HIGH: 3, MEDIUM: 2, LOW: 1 };
  const categoryWords: Record<MemoryCategory, string[]> = {
    PERSONAL: ['about', 'me', 'personal'],
    GOAL: ['goal', 'focus', 'priority', 'plan'],
    PROJECT: ['project', 'work', 'build', 'deployment'],
    PEOPLE: ['person', 'people', 'team'],
    PREFERENCE: ['prefer', 'preference', 'style', 'response'],
    DECISION: ['decision', 'decided'],
    IMPORTANT_CONTEXT: ['context', 'remember', 'know'],
  };
  const ranked = candidates.map((memory) => {
    const searchable = `${memory.title} ${memory.content}`.toLowerCase();
    const keywordScore = words.reduce((score, word) => score + (searchable.includes(word) ? 4 : 0), 0);
    const categoryScore = categoryWords[memory.category].some((word) => words.includes(word)) ? 3 : 0;
    const ageDays = (now - memory.updatedAt.getTime()) / 86_400_000;
    const recencyScore = Math.max(0, 2 - ageDays / 30);
    return { memory, score: keywordScore + categoryScore + importanceScore[memory.importance] + recencyScore };
  });
  ranked.sort((left, right) => right.score - left.score || right.memory.updatedAt.getTime() - left.memory.updatedAt.getTime());
  const result = ranked.filter(({ score }) => score >= 1).slice(0, clampLimit(limit)).map(({ memory }) => memory);
  if (result.length) await prisma.memory.updateMany({ where: { userId, id: { in: result.map((memory) => memory.id) } }, data: { lastAccessedAt: new Date() } });
  return result;
}

export async function findSimilarMemory(
  prisma: PrismaClient,
  userId: string,
  title: string,
  content: string,
  category?: MemoryCategory,
) {
  const candidates = await prisma.memory.findMany({ where: { ...activeWhere(userId), ...(category ? { category } : {}) }, take: 100 });
  const incoming = new Set(tokens(`${title} ${content}`));
  return candidates
    .map((memory) => {
      const existing = new Set(tokens(`${memory.title} ${memory.content}`));
      const overlap = [...incoming].filter((token) => existing.has(token)).length;
      return { memory, score: overlap / Math.max(incoming.size, existing.size, 1) };
    })
    .filter(({ score }) => score >= 0.6)
    .sort((left, right) => right.score - left.score)[0]?.memory ?? null;
}

export async function touchMemory(prisma: PrismaClient, userId: string, memoryId: string) {
  await getMemory(prisma, userId, memoryId);
  return prisma.memory.update({ where: { id: memoryId }, data: { lastAccessedAt: new Date() } });
}
