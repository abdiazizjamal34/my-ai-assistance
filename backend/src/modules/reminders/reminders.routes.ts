import { Request, Router } from 'express';

import { prisma } from '../../config/database';
import { UserRequest } from '../../middleware/user-context';
import { cancelReminder, createReminder, getReminder, getReminders, updateReminder, updateReminderStatus } from './reminders.service';

export const remindersRouter = Router();
const userId = (request: Request) => (request as UserRequest).userId;

remindersRouter.get('/', async (request, response) => {
  const reminders = await getReminders(prisma, userId(request), {
    status: typeof request.query.status === 'string' ? request.query.status : undefined,
    upcoming: typeof request.query.upcoming === 'string' ? request.query.upcoming : undefined,
  });
  response.json({ data: reminders });
});

remindersRouter.post('/', async (request, response) => {
  const reminder = await createReminder(prisma, userId(request), request.body);
  response.status(201).json({ data: reminder });
});

remindersRouter.get('/:id', async (request, response) => {
  const reminder = await getReminder(prisma, userId(request), request.params.id);
  response.json({ data: reminder });
});

remindersRouter.put('/:id', async (request, response) => {
  const reminder = await updateReminder(prisma, userId(request), request.params.id, request.body);
  response.json({ data: reminder });
});

remindersRouter.patch('/:id/status', async (request, response) => {
  const reminder = await updateReminderStatus(prisma, userId(request), request.params.id, request.body.status);
  response.json({ data: reminder });
});

remindersRouter.delete('/:id', async (request, response) => {
  const reminder = await cancelReminder(prisma, userId(request), request.params.id);
  response.json({ data: reminder });
});