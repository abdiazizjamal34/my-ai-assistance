import { PrismaClient, TaskStatus, ReminderStatus } from '@prisma/client';

import { getUserTimezone, getLocalDayRange } from '../shared/date-range';

export type DashboardPayload = {
  greetingName: string | null;
  todayTaskCount: number;
  overdueTaskCount: number;
  upcomingReminderCount: number;
  completedTodayCount: number;
  nextReminderAt: string | null;
  nextReminderTitle: string | null;
  currentFocusCount: number;
};

export async function getDashboard(
  prisma: PrismaClient,
  userId: string,
): Promise<DashboardPayload> {
  const timezone = await getUserTimezone(prisma, userId);
  const range = getLocalDayRange(new Date(), timezone);

  const [
    profile,
    todayTasks,
    overdueTasks,
    upcomingReminders,
    completedToday,
    nextReminder,
    inProgressTasks,
  ] = await Promise.all([
    prisma.user.findUnique({
      where: { id: userId },
      select: { firstName: true, displayName: true },
    }),
    prisma.task.count({
      where: {
        userId,
        status: { in: [TaskStatus.TODO, TaskStatus.IN_PROGRESS] },
        dueDate: { gte: range.start, lt: range.end },
      },
    }),
    prisma.task.count({
      where: {
        userId,
        status: { in: [TaskStatus.TODO, TaskStatus.IN_PROGRESS] },
        dueDate: { lt: range.start },
      },
    }),
    prisma.reminder.count({
      where: {
        userId,
        status: ReminderStatus.PENDING,
        remindAt: { gte: new Date() },
      },
    }),
    prisma.task.count({
      where: {
        userId,
        status: TaskStatus.COMPLETED,
        completedAt: { gte: range.start, lt: range.end },
      },
    }),
    prisma.reminder.findFirst({
      where: {
        userId,
        status: ReminderStatus.PENDING,
        remindAt: { gte: new Date() },
      },
      orderBy: { remindAt: 'asc' },
      select: { remindAt: true, title: true },
    }),
    prisma.task.count({
      where: {
        userId,
        status: TaskStatus.IN_PROGRESS,
      },
    }),
  ]);

  const greetingName = (profile?.firstName?.trim() ||
    profile?.displayName?.trim() ||
    null) as string | null;

  return {
    greetingName,
    todayTaskCount: todayTasks,
    overdueTaskCount: overdueTasks,
    upcomingReminderCount: upcomingReminders,
    completedTodayCount: completedToday,
    nextReminderAt: nextReminder?.remindAt.toISOString() ?? null,
    nextReminderTitle: nextReminder?.title ?? null,
    currentFocusCount: inProgressTasks,
  };
}