import { HttpError } from '../../middleware/error-handler';

export function requireObject(value: unknown): Record<string, unknown> {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) {
    throw new HttpError(400, 'Request body must be an object.');
  }
  return value as Record<string, unknown>;
}

export function optionalString(
  input: Record<string, unknown>,
  key: string,
): string | undefined {
  const value = input[key];
  if (value === undefined || value === null) return undefined;
  if (typeof value !== 'string') throw new HttpError(400, `${key} must be a string.`);
  return value.trim();
}

export function requiredString(
  input: Record<string, unknown>,
  key: string,
): string {
  const value = optionalString(input, key);
  if (!value) throw new HttpError(400, `${key} is required.`);
  return value;
}

export function optionalBoolean(
  input: Record<string, unknown>,
  key: string,
): boolean | undefined {
  const value = input[key];
  if (value === undefined || value === null) return undefined;
  if (typeof value !== 'boolean') throw new HttpError(400, `${key} must be a boolean.`);
  return value;
}

export function optionalEnum<T extends string>(
  input: Record<string, unknown>,
  key: string,
  allowed: readonly T[],
): T | undefined {
  const value = input[key];
  if (value === undefined || value === null) return undefined;
  if (typeof value !== 'string' || !allowed.includes(value as T)) {
    throw new HttpError(400, `${key} has an invalid value.`);
  }
  return value as T;
}