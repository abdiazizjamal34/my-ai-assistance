import { MemoryCategory, MemoryImportance, MemorySource, MemoryStatus } from '@prisma/client';

import { HttpError } from '../middleware/error-handler';
import { optionalEnum, optionalString, requireObject, requiredString } from '../modules/shared/validation';

const categories = Object.values(MemoryCategory);
const importances = Object.values(MemoryImportance);
const statuses = Object.values(MemoryStatus);
const sources = Object.values(MemorySource);

function parseDate(value: string | undefined, field: string): Date | null | undefined {
  if (value === undefined) return undefined;
  if (!value) return null;
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) throw new HttpError(400, `${field} must be a valid date.`);
  return date;
}

function parseConfidence(input: Record<string, unknown>, partial: boolean): number | undefined {
  const value = input.confidence;
  if (value === undefined || value === null) return partial ? undefined : 1;
  if (typeof value !== 'number' || !Number.isFinite(value) || value < 0 || value > 1) {
    throw new HttpError(400, 'confidence must be a number between 0 and 1.');
  }
  return value;
}

export function parseMemoryInput(body: unknown, partial = false) {
  const input = requireObject(body);
  const title = partial ? optionalString(input, 'title') : requiredString(input, 'title');
  const content = partial ? optionalString(input, 'content') : requiredString(input, 'content');
  const expiresAt = parseDate(optionalString(input, 'expiresAt'), 'expiresAt');
  const confidence = parseConfidence(input, partial);
  return {
    ...(title === undefined ? {} : { title }),
    ...(content === undefined ? {} : { content }),
    category: optionalEnum(input, 'category', categories),
    importance: optionalEnum(input, 'importance', importances),
    status: optionalEnum(input, 'status', statuses),
    source: optionalEnum(input, 'source', sources),
    ...(confidence === undefined ? {} : { confidence }),
    ...(expiresAt === undefined ? {} : { expiresAt }),
    sourceConversationId: optionalString(input, 'sourceConversationId'),
    metadata: input.metadata,
  };
}

export function parseMemoryFilters(query: Record<string, unknown>) {
  return {
    category: optionalEnum(query, 'category', categories),
    importance: optionalEnum(query, 'importance', importances),
    status: optionalEnum(query, 'status', statuses),
  };
}
