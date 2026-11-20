import { Router } from 'express';

import { prisma } from '../../config/database';
import { requireObject, requiredString } from '../shared/validation';
import { login, register } from './auth.service';

export const authRouter = Router();

authRouter.post('/register', async (request, response) => {
  const body = requireObject(request.body);
  const email = requiredString(body, 'email');
  const password = requiredString(body, 'password');
  const displayName =
    typeof body.displayName === 'string' ? body.displayName : undefined;
  const result = await register(prisma, email, password, displayName);
  response.status(201).json({ data: result });
});

authRouter.post('/login', async (request, response) => {
  const body = requireObject(request.body);
  const email = requiredString(body, 'email');
  const password = requiredString(body, 'password');
  const result = await login(prisma, email, password);
  response.json({ data: result });
});