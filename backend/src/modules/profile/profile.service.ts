import { PrismaClient } from '@prisma/client';

import { HttpError } from '../../middleware/error-handler';
import {
  optionalString,
  requireObject,
} from '../shared/validation';

export const profileFields = [
  'firstName',
  'lastName',
  'displayName',
  'email',
  'profileImageUrl',
  'bio',
  'timezone',
  'preferredLanguage',
  'locationCountry',
] as const;

export function parseProfileInput(body: unknown): Record<string, string | null> {
  const input = requireObject(body);
  const data: Record<string, string | null> = {};
  for (const field of profileFields) {
    if (field in input) data[field] = optionalString(input, field) ?? null;
  }

  if (data.email && !/^\S+@\S+\.\S+$/.test(data.email)) {
    throw new HttpError(400, 'email must be a valid email address.');
  }
  return data;
}

export async function getProfile(prisma: PrismaClient, userId: string) {
  return prisma.user.upsert({
    where: { id: userId },
    update: {},
    create: { id: userId },
    select: {
      id: true,
      firstName: true,
      lastName: true,
      displayName: true,
      email: true,
      profileImageUrl: true,
      bio: true,
      timezone: true,
      preferredLanguage: true,
      locationCountry: true,
      createdAt: true,
      updatedAt: true,
    },
  });
}

export async function updateProfile(
  prisma: PrismaClient,
  userId: string,
  body: unknown,
) {
  const data = parseProfileInput(body);
  return prisma.user.upsert({
    where: { id: userId },
    update: data,
    create: { id: userId, ...data },
    select: {
      id: true,
      firstName: true,
      lastName: true,
      displayName: true,
      email: true,
      profileImageUrl: true,
      bio: true,
      timezone: true,
      preferredLanguage: true,
      locationCountry: true,
      createdAt: true,
      updatedAt: true,
    },
  });
}