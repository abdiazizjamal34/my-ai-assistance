import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { PrismaClient } from '@prisma/client';

import { env } from '../../config/env';
import { HttpError } from '../../middleware/error-handler';

const SALT_ROUNDS = 10;
const TOKEN_TTL = '30d';

export type AuthResult = {
  token: string;
  userId: string;
  email: string | null;
  displayName: string | null;
};

function signToken(userId: string): string {
  return jwt.sign({ sub: userId }, env.jwtSecret, { expiresIn: TOKEN_TTL });
}

export function verifyToken(token: string): string {
  try {
    const payload = jwt.verify(token, env.jwtSecret) as { sub?: string };
    if (!payload.sub) throw new Error('Missing sub claim.');
    return payload.sub;
  } catch {
    throw new HttpError(401, 'Invalid or expired token.', 'INVALID_TOKEN');
  }
}

export async function register(
  prisma: PrismaClient,
  email: string,
  password: string,
  displayName?: string,
): Promise<AuthResult> {
  const cleanEmail = email.trim().toLowerCase();
  if (!/^\S+@\S+\.\S+$/.test(cleanEmail)) {
    throw new HttpError(400, 'email must be a valid email address.');
  }
  if (password.length < 8) {
    throw new HttpError(400, 'password must be at least 8 characters.');
  }

  const existing = await prisma.user.findFirst({ where: { email: cleanEmail } });
  if (existing) {
    throw new HttpError(409, 'Email is already registered.');
  }

  const passwordHash = await bcrypt.hash(password, SALT_ROUNDS);
  const user = await prisma.user.create({
    data: {
      email: cleanEmail,
      passwordHash,
      displayName: displayName?.trim() || null,
    },
  });

  return {
    token: signToken(user.id),
    userId: user.id,
    email: user.email,
    displayName: user.displayName,
  };
}

export async function login(
  prisma: PrismaClient,
  email: string,
  password: string,
): Promise<AuthResult> {
  const cleanEmail = email.trim().toLowerCase();
  const user = await prisma.user.findFirst({ where: { email: cleanEmail } });
  if (!user || !user.passwordHash) {
    throw new HttpError(401, 'Invalid email or password.', 'INVALID_CREDENTIALS');
  }
  const ok = await bcrypt.compare(password, user.passwordHash);
  if (!ok) {
    throw new HttpError(401, 'Invalid email or password.', 'INVALID_CREDENTIALS');
  }
  return {
    token: signToken(user.id),
    userId: user.id,
    email: user.email,
    displayName: user.displayName,
  };
}