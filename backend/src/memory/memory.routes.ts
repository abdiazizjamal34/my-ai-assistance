import { Request, Router } from 'express';

import { prisma } from '../config/database';
import { UserRequest } from '../middleware/user-context';
import {
  archiveMemory,
  createMemory,
  deleteMemory,
  getMemory,
  getRelevantMemories,
  listMemories,
  searchMemories,
  updateMemory,
} from './memory.service';

export const memoryRouter = Router();

const userId = (request: Request) =>
  (request as UserRequest).userId;

memoryRouter.get('/search', async (request, response) => {
  const memories = await searchMemories(prisma, userId(request), String(request.query.q ?? ''), {
    category: request.query.category as never,
    importance: request.query.importance as never,
    status: request.query.status as never,
    limit: request.query.limit ? Number(request.query.limit) : undefined,
  });
  response.json({ data: memories });
});

memoryRouter.get('/relevant', async (request, response) => {
  const memories = await getRelevantMemories(
    prisma,
    userId(request),
    String(request.query.q ?? ''),
    request.query.limit ? Number(request.query.limit) : undefined,
  );
  response.json({ data: memories });
});

memoryRouter.get('/', async (request, response) => {
  const memories = await listMemories(prisma, userId(request), request.query as Record<string, unknown>);
  response.json({ data: memories });
});

memoryRouter.post('/', async (request, response) => {
  const memory = await createMemory(prisma, userId(request), request.body);
  response.status(201).json({ data: memory });
});

memoryRouter.get('/:id', async (request, response) => {
  const memory = await getMemory(prisma, userId(request), request.params.id);
  response.json({ data: memory });
});

memoryRouter.put('/:id', async (request, response) => {
  const memory = await updateMemory(prisma, userId(request), request.params.id, request.body);
  response.json({ data: memory });
});

memoryRouter.delete('/:id', async (request, response) => {
  const memory = await deleteMemory(prisma, userId(request), request.params.id);
  response.json({ data: memory });
});

memoryRouter.post('/:id/archive', async (request, response) => {
  const memory = await archiveMemory(prisma, userId(request), request.params.id);
  response.json({ data: memory });
});
