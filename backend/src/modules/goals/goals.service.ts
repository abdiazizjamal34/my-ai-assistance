import { GoalStatus, PrismaClient } from '@prisma/client';

import { HttpError } from '../../middleware/error-handler';
import {
  optionalEnum,
  optionalString,
  requireObject,
  requiredString,
} from '../shared/validation';

const categories = ['CAREER', 'BUSINESS', 'PERSONAL', 'LEARNING', 'FINANCIAL', 'HEALTH', 'OTHER'] as const;
const priorities = ['HIGH', 'MEDIUM', 'LOW'] as const;
const statuses = ['ACTIVE', 'COMPLETED', 'PAUSED', 'CANCELLED'] as const;

function parseDate(value: string | undefined): Date | null | undefined {
  if (value === undefined) return undefined;
  if (!value) return null;
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) throw new HttpError(400, 'targetDate must be a valid date.');
  return date;
}

export function parseGoalInput(body: unknown, partial = false) {
  const input = requireObject(body);
  const title = partial ? optionalString(input, 'title') : requiredString(input, 'title');
  const targetDate = parseDate(optionalString(input, 'targetDate'));
  return {
    ...(title === undefined ? {} : { title }),
    description: optionalString(input, 'description'),
    category: optionalEnum(input, 'category', categories),
    priority: optionalEnum(input, 'priority', priorities),
    status: optionalEnum(input, 'status', statuses),
    ...(targetDate === undefined ? {} : { targetDate }),
  };
}

export async function listGoals(prisma: PrismaClient, userId: string) {
  return prisma.goal.findMany({
    where: { userId },
    orderBy: [{ status: 'asc' }, { targetDate: 'asc' }, { createdAt: 'desc' }],
  });
}

export async function createGoal(prisma: PrismaClient, userId: string, body: unknown) {
  const input = parseGoalInput(body);
  if (!input.title) throw new HttpError(400, 'title is required.');
  return prisma.goal.create({ data: { userId, ...input, title: input.title } });
}

export async function getGoal(prisma: PrismaClient, userId: string, goalId: string) {
  const goal = await prisma.goal.findFirst({ where: { id: goalId, userId } });
  if (!goal) throw new HttpError(404, 'Goal not found.');
  return goal;
}

export async function updateGoal(
  prisma: PrismaClient,
  userId: string,
  goalId: string,
  body: unknown,
) {
  await getGoal(prisma, userId, goalId);
  const input = parseGoalInput(body, true);
  const data = Object.fromEntries(
    Object.entries(input).filter(([, value]) => value !== undefined),
  );
  return prisma.goal.update({ where: { id: goalId }, data });
}

export async function cancelGoal(prisma: PrismaClient, userId: string, goalId: string) {
  await getGoal(prisma, userId, goalId);
  return prisma.goal.update({
    where: { id: goalId },
    data: { status: GoalStatus.CANCELLED },
  });
}