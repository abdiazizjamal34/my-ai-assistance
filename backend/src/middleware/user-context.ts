import { NextFunction, Request, Response } from 'express';

import { env } from '../config/env';
import { prisma } from '../config/database';

export type UserRequest = Request & { userId: string };

class HttpError extends Error {
  constructor(
    public readonly statusCode: number,
    message: string,
  ) {
    super(message);
    this.name = 'HttpError';
  }
}

export async function requireUserContext(
  request: Request,
  response: Response,
  next: NextFunction,
): Promise<void> {
  const userId = request.header('x-user-id') ?? env.defaultUserId;
  if (!userId || !/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(userId)) {
    response.status(400).json({ error: 'A user context is required.' });
    return;
  }

  await prisma.user.upsert({
    where: { id: userId },
    update: {},
    create: { id: userId },
  });
  (request as UserRequest).userId = userId;
  next();
}


export function asUserRequest(request: Request): UserRequest {
  const userId = (request as { userId?: string }).userId;
  if (!userId) {
    throw new HttpError(500, 'User context is missing on this request.');
  }
  return request as unknown as UserRequest;
}