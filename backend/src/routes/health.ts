import { Router } from 'express';

import { prisma } from '../config/database';

export const healthRouter = Router();

healthRouter.get('/', async (_request, response) => {
  try {
    await prisma.$queryRaw`SELECT 1`;
    return response.json({
      status: 'ok',
      service: 'personal-ai-backend',
      database: 'ok',
    });
  } catch {
    return response.status(503).json({
      status: 'degraded',
      service: 'personal-ai-backend',
      database: 'unavailable',
    });
  }
});