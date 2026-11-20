import { PrismaClient, TaskStatus } from '@prisma/client';

import { HttpError } from '../../middleware/error-handler';
import { getLocalDayRange, getUserTimezone } from '../shared/date-range';
import { optionalEnum, optionalString, requireObject, requiredString } from '../shared/validation';

const priorities = ['URGENT', 'HIGH', 'MEDIUM', 'LOW'] as const;
const statuses = ['TODO', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'] as const;
const sources = ['USER', 'AI_CONVERSATION', 'MANUAL', 'INTEGRATION'] as const;

function parseDate(value: string | undefined, field: string): Date | null | undefined {
  if (value === undefined) return undefined;
  if (!value) return null;
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) throw new HttpError(400, `${field} must be a valid date.`);
  return date;
}

export function parseTaskInput(body: unknown, partial = false) {
  const input = requireObject(body);
  const title = partial ? optionalString(input, 'title') : requiredString(input, 'title');
  return {
    ...(title === undefined ? {} : { title }),
    description: optionalString(input, 'description'),
    priority: optionalEnum(input, 'priority', priorities),
    status: optionalEnum(input, 'status', statuses),
    projectId: optionalString(input, 'projectId'),
    dueDate: parseDate(optionalString(input, 'dueDate'), 'dueDate'),
    reminderAt: parseDate(optionalString(input, 'reminderAt'), 'reminderAt'),
    source: optionalEnum(input, 'source', sources),
  };
}

function lifecycleData(status: TaskStatus) {
  const now = new Date();
  return {
    status,
    completedAt: status === TaskStatus.COMPLETED ? now : null,
    cancelledAt: status === TaskStatus.CANCELLED ? now : null,
  };
}

function taskWhere(userId: string, filters: Record<string, unknown> = {}) {
  return { userId, ...filters };
}

export async function createTask(prisma: PrismaClient, userId: string, body: unknown) {
  const input = parseTaskInput(body);
  if (!input.title) throw new HttpError(400, 'title is required.');
  const { status, ...data } = input;
  return prisma.task.create({
    data: {
      userId,
      ...data,
      title: input.title,
      ...(status ? lifecycleData(status as TaskStatus) : {}),
    },
  });
}

export async function getTask(prisma: PrismaClient, userId: string, taskId: string) {
  const task = await prisma.task.findFirst({ where: { id: taskId, userId } });
  if (!task) throw new HttpError(404, 'Task not found.');
  return task;
}

export async function updateTask(prisma: PrismaClient, userId: string, taskId: string, body: unknown) {
  await getTask(prisma, userId, taskId);
  const input = parseTaskInput(body, true);
  const { status, ...rest } = input;
  const data = Object.fromEntries(Object.entries(rest).filter(([, value]) => value !== undefined));
  return prisma.task.update({
    where: { id: taskId },
    data: { ...data, ...(status ? lifecycleData(status as TaskStatus) : {}) },
  });
}

export async function updateTaskStatus(prisma: PrismaClient, userId: string, taskId: string, status: string) {
  const parsed = optionalEnum({ status }, 'status', statuses);
  if (!parsed) throw new HttpError(400, 'status is required.');
  await getTask(prisma, userId, taskId);
  return prisma.task.update({ where: { id: taskId }, data: lifecycleData(parsed as TaskStatus) });
}

export async function cancelTask(prisma: PrismaClient, userId: string, taskId: string) {
  return updateTaskStatus(prisma, userId, taskId, TaskStatus.CANCELLED);
}

export async function getTasks(prisma: PrismaClient, userId: string, filters: { status?: string; priority?: string; date?: string; completed?: string }) {
  const where: Record<string, unknown> = taskWhere(userId);
  if (filters.status) where.status = optionalEnum(filters, 'status', statuses);
  if (filters.priority) where.priority = optionalEnum(filters, 'priority', priorities);
  if (filters.completed === 'true') where.status = TaskStatus.COMPLETED;
  if (filters.date) {
    const timezone = await getUserTimezone(prisma, userId);
    const range = getLocalDayRange(new Date(), timezone);
    if (filters.date === 'today') where.dueDate = { gte: range.start, lt: range.end };
    if (filters.date === 'upcoming') where.dueDate = { gte: range.end };
    if (filters.date === 'overdue') where.dueDate = { lt: range.start };
  }
  if (!filters.status && filters.completed !== 'true' && filters.date !== 'completed') {
    where.status = { not: TaskStatus.CANCELLED };
  }
  return prisma.task.findMany({ where, orderBy: [{ dueDate: 'asc' }, { createdAt: 'desc' }] });
}

export const getTodayTasks = (prisma: PrismaClient, userId: string) => getTasks(prisma, userId, { date: 'today' });
export const getUpcomingTasks = (prisma: PrismaClient, userId: string) => getTasks(prisma, userId, { date: 'upcoming' });
export const getPendingTasks = (prisma: PrismaClient, userId: string) =>
  prisma.task.findMany({
    where: { userId, status: { in: [TaskStatus.TODO, TaskStatus.IN_PROGRESS] } },
    orderBy: [{ dueDate: 'asc' }, { createdAt: 'desc' }],
  });
export const getCompletedTasks = (prisma: PrismaClient, userId: string) => getTasks(prisma, userId, { completed: 'true' });
export const getOverdueTasks = (prisma: PrismaClient, userId: string) => getTasks(prisma, userId, { date: 'overdue' });