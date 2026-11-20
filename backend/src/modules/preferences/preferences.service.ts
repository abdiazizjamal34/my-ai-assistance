import { PrismaClient } from '@prisma/client';

import { HttpError } from '../../middleware/error-handler';
import { requireObject, optionalBoolean, optionalEnum, optionalString } from '../shared/validation';

const dateFormats = ['DMY', 'MDY', 'YMD'] as const;
const timeFormats = ['H12', 'H24'] as const;
const weekStartDays = ['SUNDAY', 'MONDAY'] as const;
const notificationPreferences = ['ALL', 'IMPORTANT', 'NONE'] as const;

export function parsePreferencesInput(body: unknown) {
  const input = requireObject(body);
  const morningPlanningTime = optionalString(input, 'morningPlanningTime');
  const eveningReviewTime = optionalString(input, 'eveningReviewTime');
  for (const [field, value] of [
    ['morningPlanningTime', morningPlanningTime],
    ['eveningReviewTime', eveningReviewTime],
  ] as const) {
    if (value !== undefined && !/^([01]\d|2[0-3]):[0-5]\d$/.test(value)) {
      throw new HttpError(400, `${field} must use HH:MM format.`);
    }
  }
  return {
    timezone: optionalString(input, 'timezone'),
    preferredLanguage: optionalString(input, 'preferredLanguage'),
    dateFormat: optionalEnum(input, 'dateFormat', dateFormats),
    timeFormat: optionalEnum(input, 'timeFormat', timeFormats),
    weekStartDay: optionalEnum(input, 'weekStartDay', weekStartDays),
    notificationPreference: optionalEnum(
      input,
      'notificationPreference',
      notificationPreferences,
    ),
    morningPlanningEnabled: optionalBoolean(input, 'morningPlanningEnabled'),
    morningPlanningTime,
    eveningReviewEnabled: optionalBoolean(input, 'eveningReviewEnabled'),
    eveningReviewTime,
  };
}

export async function getPreferences(prisma: PrismaClient, userId: string) {
  return prisma.userPreferences.upsert({
    where: { userId },
    update: {},
    create: { userId },
  });
}

export async function updatePreferences(
  prisma: PrismaClient,
  userId: string,
  body: unknown,
) {
  const input = parsePreferencesInput(body);
  const data = Object.fromEntries(
    Object.entries(input).filter(([, value]) => value !== undefined),
  );
  return prisma.userPreferences.upsert({
    where: { userId },
    update: data,
    create: { userId, ...data },
  });
}