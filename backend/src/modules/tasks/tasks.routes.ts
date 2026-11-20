import { Request, Router } from 'express';

import { prisma } from '../../config/database';
import { UserRequest } from '../../middleware/user-context';
import { cancelTask, createTask, getTask, getTasks, updateTask, updateTaskStatus } from './tasks.service';

export const tasksRouter = Router();
const userId = (request: Request) => (request as UserRequest).userId;

tasksRouter.get('/', async (request, response) => {
  const tasks = await getTasks(prisma, userId(request), {
    status: typeof request.query.status === 'string' ? request.query.status : undefined,
    priority: typeof request.query.priority === 'string' ? request.query.priority : undefined,
    date: typeof request.query.date === 'string' ? request.query.date : undefined,
    completed: typeof request.query.completed === 'string' ? request.query.completed : undefined,
  });
  response.json({ data: tasks });
});

tasksRouter.post('/', async (request, response) => {
  const task = await createTask(prisma, userId(request), request.body);
  response.status(201).json({ data: task });
});

tasksRouter.get('/:id', async (request, response) => {
  const task = await getTask(prisma, userId(request), request.params.id);
  response.json({ data: task });
});

tasksRouter.put('/:id', async (request, response) => {
  const task = await updateTask(prisma, userId(request), request.params.id, request.body);
  response.json({ data: task });
});

tasksRouter.patch('/:id/status', async (request, response) => {
  const task = await updateTaskStatus(prisma, userId(request), request.params.id, request.body.status);
  response.json({ data: task });
});

tasksRouter.delete('/:id', async (request, response) => {
  const task = await cancelTask(prisma, userId(request), request.params.id);
  response.json({ data: task });
});