import { Router } from 'express';

import { prisma } from '../../config/database';
import { UserRequest } from '../../middleware/user-context';
import { getProfile, updateProfile } from './profile.service';

export const profileRouter = Router();

profileRouter.get('/', async (request, response) => {
  const user = await getProfile(prisma, (request as UserRequest).userId);
  response.json({ data: user });
});

profileRouter.put('/', async (request, response) => {
  const user = await updateProfile(
    prisma,
    (request as UserRequest).userId,
    request.body,
  );
  response.json({ data: user });
});