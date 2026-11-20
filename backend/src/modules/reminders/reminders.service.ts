import { PrismaClient, ReminderStatus } from '@prisma/client';

import { HttpError } from '../../middleware/error-handler';
import { optionalEnum, optionalString, requireObject, requiredString } from '../shared/validation';

const statuses = ['PENDING', 'COMPLETED', 'CANCELLED'] as const;

function parseRemindAt(value: string | undefined): Date | undefined {
  if (!value) throw new HttpError(400, 'remindAt is required.');
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) throw new HttpError(400, 'remindAt must be a valid date.');
  return date;
}

export function parseReminderInput(body: unknown, partial = false) {
  const input = requireObject(body);
  const title = partial ? optionalString(input, 'title') : requiredString(input, 'title');
  const remindAtValue = optionalString(input, 'remindAt');
  return {
    ...(title === undefined ? {} : { title }),
    description: optionalString(input, 'description'),
    taskId: optionalString(input, 'taskId'),
    ...(remindAtValue === undefined && partial ? {} : { remindAt: parseRemindAt(remindAtValue) }),
    status: optionalEnum(input, 'status', statuses),
  };
}

async function ensureTaskOwnership(prisma: PrismaClient, userId: string, taskId: string | null | undefined) {
  if (!taskId) return;
  const task = await prisma.task.findFirst({ where: { id: taskId, userId }, select: { id: true } });
  if (!task) throw new HttpError(400, 'taskId does not belong to this user.');
}

function lifecycleData(status: ReminderStatus) {
  const now = new Date();
  return {
    status,
    completedAt: status === ReminderStatus.COMPLETED ? now : null,
    cancelledAt: status === ReminderStatus.CANCELLED ? now : null,
  };
}

export async function createReminder(prisma: PrismaClient, userId: string, body: unknown) {
  const input = parseReminderInput(body);
  if (!input.title || !input.remindAt) throw new HttpError(400, 'title and remindAt are required.');
  await ensureTaskOwnership(prisma, userId, input.taskId);
  const { status, ...data } = input;
  return prisma.reminder.create({
    data: {
      userId,
      ...data,
      title: input.title,
      remindAt: input.remindAt,
      ...(status ? lifecycleData(status as ReminderStatus) : {}),
    },
  });
}

export async function getReminder(prisma: PrismaClient, userId: string, reminderId: string) {
  const reminder = await prisma.reminder.findFirst({ where: { id: reminderId, userId } });
  if (!reminder) throw new HttpError(404, 'Reminder not found.');
  return reminder;
}

export async function updateReminder(prisma: PrismaClient, userId: string, reminderId: string, body: unknown) {
  await getReminder(prisma, userId, reminderId);
  const input = parseReminderInput(body, true);
  await ensureTaskOwnership(prisma, userId, input.taskId);
  const { status, ...rest } = input;
  const data = Object.fromEntries(Object.entries(rest).filter(([, value]) => value !== undefined));
  return prisma.reminder.update({
    where: { id: reminderId },
    data: { ...data, ...(status ? lifecycleData(status as ReminderStatus) : {}) },
  });
}

export async function updateReminderStatus(prisma: PrismaClient, userId: string, reminderId: string, status: string) {
  const parsed = optionalEnum({ status }, 'status', statuses);
  if (!parsed) throw new HttpError(400, 'status is required.');
  await getReminder(prisma, userId, reminderId);
  return prisma.reminder.update({ where: { id: reminderId }, data: lifecycleData(parsed as ReminderStatus) });
}

export const cancelReminder = (prisma: PrismaClient, userId: string, reminderId: string) =>
  updateReminderStatus(prisma, userId, reminderId, ReminderStatus.CANCELLED);

export async function getReminders(
  prisma: PrismaClient,
  userId: string,
  filters: { status?: string; upcoming?: string },
) {
  const where: Record<string, unknown> = { userId };
  if (filters.status) where.status = optionalEnum(filters, 'status', statuses);
  else where.status = ReminderStatus.PENDING;
  if (filters.upcoming === 'true') where.remindAt = { gte: new Date() };
  return prisma.reminder.findMany({ where, orderBy: { remindAt: 'asc' } });
}

export const getUpcomingReminders = async (prisma: PrismaClient, userId: string) => {
  return getReminders(prisma, userId, { upcoming: 'true' });
};