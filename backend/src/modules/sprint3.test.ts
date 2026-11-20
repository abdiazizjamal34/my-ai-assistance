import 'dotenv/config';

import assert from 'node:assert/strict';
import { after, before, describe, test } from 'node:test';

import { prisma } from '../config/database';
import {
  cancelTask,
  createTask,
  getOverdueTasks,
  getTask,
  getTodayTasks,
  getUpcomingTasks,
  updateTask,
  updateTaskStatus,
} from './tasks/tasks.service';
import {
  cancelReminder,
  createReminder,
  getReminder,
  getReminders,
  updateReminderStatus,
} from './reminders/reminders.service';

const primaryUserId = '00000000-0000-4000-8000-000000000201';
const otherUserId = '00000000-0000-4000-8000-000000000202';
let taskId = '';
let reminderId = '';

before(async () => {
  await prisma.user.deleteMany({ where: { id: { in: [primaryUserId, otherUserId] } } });
  await prisma.user.createMany({ data: [{ id: primaryUserId }, { id: otherUserId }] });
});

after(async () => {
  await prisma.user.deleteMany({ where: { id: { in: [primaryUserId, otherUserId] } } });
  await prisma.$disconnect();
});

describe('Sprint 3 task and reminder services', () => {
  test('creates a task with defaults', async () => {
    const task = await createTask(prisma, primaryUserId, { title: 'Review sprint plan' });
    taskId = task.id;
    assert.equal(task.priority, 'MEDIUM');
    assert.equal(task.status, 'TODO');
    assert.equal(task.source, 'USER');
  });

  test('updates a task', async () => {
    const task = await updateTask(prisma, primaryUserId, taskId, {
      description: 'Review the next implementation slice.',
      priority: 'HIGH',
    });
    assert.equal(task.priority, 'HIGH');
    assert.equal(task.description, 'Review the next implementation slice.');
  });

  test('creates today, upcoming, and overdue task dates', async () => {
    await createTask(prisma, primaryUserId, {
      title: 'Today task',
      dueDate: new Date(Date.now() + 60_000).toISOString(),
    });
    await createTask(prisma, primaryUserId, {
      title: 'Upcoming task',
      dueDate: new Date(Date.now() + 3 * 24 * 60 * 60 * 1000).toISOString(),
    });
    await createTask(prisma, primaryUserId, {
      title: 'Overdue task',
      dueDate: new Date(Date.now() - 3 * 24 * 60 * 60 * 1000).toISOString(),
    });

    assert.ok((await getTodayTasks(prisma, primaryUserId)).some((task) => task.title === 'Today task'));
    assert.ok((await getUpcomingTasks(prisma, primaryUserId)).some((task) => task.title === 'Upcoming task'));
    assert.ok((await getOverdueTasks(prisma, primaryUserId)).some((task) => task.title === 'Overdue task'));
  });

  test('completes and reopens a task with timestamps', async () => {
    const completed = await updateTaskStatus(prisma, primaryUserId, taskId, 'COMPLETED');
    assert.equal(completed.status, 'COMPLETED');
    assert.ok(completed.completedAt);

    const reopened = await updateTaskStatus(prisma, primaryUserId, taskId, 'IN_PROGRESS');
    assert.equal(reopened.status, 'IN_PROGRESS');
    assert.equal(reopened.completedAt, null);
  });

  test('creates a task reminder', async () => {
    const reminder = await createReminder(prisma, primaryUserId, {
      title: 'Review task reminder',
      taskId,
      remindAt: new Date(Date.now() + 3_600_000).toISOString(),
    });
    reminderId = reminder.id;
    assert.equal(reminder.status, 'PENDING');
    assert.equal(reminder.taskId, taskId);
  });

  test('lists and completes reminders', async () => {
    const reminders = await getReminders(prisma, primaryUserId, {});
    assert.ok(reminders.some((reminder) => reminder.id === reminderId));
    const completed = await updateReminderStatus(prisma, primaryUserId, reminderId, 'COMPLETED');
    assert.equal(completed.status, 'COMPLETED');
    assert.ok(completed.completedAt);
  });

  test('enforces task and reminder ownership', async () => {
    await assert.rejects(() => getTask(prisma, otherUserId, taskId), /Task not found/);
    await assert.rejects(() => getReminder(prisma, otherUserId, reminderId), /Reminder not found/);
    await assert.rejects(
      () => createReminder(prisma, otherUserId, {
        title: 'Invalid ownership',
        taskId,
        remindAt: new Date(Date.now() + 3_600_000).toISOString(),
      }),
      /does not belong/,
    );
  });

  test('rejects invalid task and reminder input', async () => {
    await assert.rejects(() => createTask(prisma, primaryUserId, {}), /title is required/);
    await assert.rejects(
      () => createTask(prisma, primaryUserId, { title: 'Bad priority', priority: 'CRITICAL' }),
      /invalid value/,
    );
    await assert.rejects(
      () => createReminder(prisma, primaryUserId, { title: 'Bad date', remindAt: 'not-a-date' }),
      /valid date/,
    );
  });

  test('cancels task and reminder without hard deletion', async () => {
    const cancelledTask = await cancelTask(prisma, primaryUserId, taskId);
    assert.equal(cancelledTask.status, 'CANCELLED');
    assert.ok(cancelledTask.cancelledAt);

    const cancelledReminder = await cancelReminder(prisma, primaryUserId, reminderId);
    assert.equal(cancelledReminder.status, 'CANCELLED');
    assert.ok(cancelledReminder.cancelledAt);
  });
});