import { Router } from 'express';

import { prisma } from '../../config/database';
import { asUserRequest } from '../../middleware/user-context';
import { getDashboard } from './dashboard.service';

export const dashboardRouter = Router();

dashboardRouter.get('/', async (request, response) => {
  const userId = asUserRequest(request).userId;
  const data = await getDashboard(prisma, userId);
  response.json({ data });
});