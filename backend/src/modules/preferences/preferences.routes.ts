import { Router } from 'express';

import { prisma } from '../../config/database';
import { UserRequest } from '../../middleware/user-context';
import { getPreferences, updatePreferences } from './preferences.service';

export const preferencesRouter = Router();

preferencesRouter.get('/', async (request, response) => {
  const preferences = await getPreferences(prisma, (request as UserRequest).userId);
  response.json({ data: preferences });
});

preferencesRouter.put('/', async (request, response) => {
  const preferences = await updatePreferences(
    prisma,
    (request as UserRequest).userId,
    request.body,
  );
  response.json({ data: preferences });
});