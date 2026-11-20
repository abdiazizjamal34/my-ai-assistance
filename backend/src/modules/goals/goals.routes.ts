import { Router } from 'express';

import { prisma } from '../../config/database';
import { UserRequest } from '../../middleware/user-context';
import {
  cancelGoal,
  createGoal,
  getGoal,
  listGoals,
  updateGoal,
} from './goals.service';

export const goalsRouter = Router();

goalsRouter.get('/', async (request, response) => {
  const goals = await listGoals(prisma, (request as UserRequest).userId);
  response.json({ data: goals });
});

goalsRouter.post('/', async (request, response) => {
  const goal = await createGoal(prisma, (request as UserRequest).userId, request.body);
  response.status(201).json({ data: goal });
});

goalsRouter.get('/:id', async (request, response) => {
  const goal = await getGoal(
    prisma,
    (request as unknown as UserRequest).userId,
    request.params.id,
  );
  response.json({ data: goal });
});

goalsRouter.put('/:id', async (request, response) => {
  const goal = await updateGoal(
    prisma,
    (request as unknown as UserRequest).userId,
    request.params.id,
    request.body,
  );
  response.json({ data: goal });
});

goalsRouter.delete('/:id', async (request, response) => {
  const goal = await cancelGoal(
    prisma,
    (request as unknown as UserRequest).userId,
    request.params.id,
  );
  response.json({ data: goal });
});