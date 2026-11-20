import { PrismaClient } from '@prisma/client';

import { requireObject, optionalEnum, optionalString } from '../shared/validation';

const personalities = ['PROFESSIONAL', 'FRIENDLY', 'DIRECT', 'SUPPORTIVE', 'STRATEGIC'] as const;
const communicationStyles = ['CONCISE', 'BALANCED', 'DETAILED'] as const;
const responseLengths = ['SHORT', 'BALANCED', 'LONG'] as const;
const proactivityLevels = ['LOW', 'MEDIUM', 'HIGH'] as const;

export function parseAssistantInput(body: unknown) {
  const input = requireObject(body);
  return {
    name: optionalString(input, 'name'),
    personality: optionalEnum(input, 'personality', personalities),
    communicationStyle: optionalEnum(input, 'communicationStyle', communicationStyles),
    responseLength: optionalEnum(input, 'responseLength', responseLengths),
    proactivity: optionalEnum(input, 'proactivity', proactivityLevels),
  };
}

export async function getAssistantProfile(prisma: PrismaClient, userId: string) {
  return prisma.assistantProfile.upsert({
    where: { userId },
    update: {},
    create: { userId },
  });
}

export async function updateAssistantProfile(
  prisma: PrismaClient,
  userId: string,
  body: unknown,
) {
  const input = parseAssistantInput(body);
  const data = Object.fromEntries(
    Object.entries(input).filter(([, value]) => value !== undefined),
  );
  return prisma.assistantProfile.upsert({
    where: { userId },
    update: data,
    create: { userId, ...data },
  });
}