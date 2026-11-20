import { Router } from 'express';

import { prisma } from '../../config/database';
import { UserRequest } from '../../middleware/user-context';
import { getAssistantProfile, updateAssistantProfile } from './assistant.service';

export const assistantRouter = Router();

assistantRouter.get('/', async (request, response) => {
  const profile = await getAssistantProfile(prisma, (request as UserRequest).userId);
  response.json({ data: profile });
});

assistantRouter.put('/', async (request, response) => {
  const profile = await updateAssistantProfile(
    prisma,
    (request as UserRequest).userId,
    request.body,
  );
  response.json({ data: profile });
});