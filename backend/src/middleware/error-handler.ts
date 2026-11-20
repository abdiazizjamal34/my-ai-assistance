import { NextFunction, Request, Response } from 'express';
import { Prisma } from '@prisma/client';

export class HttpError extends Error {
  constructor(
    public readonly statusCode: number,
    message: string,
    public readonly code?: string,
  ) {
    super(message);
    this.name = 'HttpError';
  }
}

type ErrorBody = {
  error: string;
  code?: string;
  details?: unknown;
};

function prismaErrorToHttp(error: Prisma.PrismaClientKnownRequestError): {
  status: number;
  body: ErrorBody;
} {
  switch (error.code) {
    case 'P2002': {
      const target = (error.meta?.target as string[] | string | undefined) ?? 'field';
      const fields = Array.isArray(target) ? target.join(', ') : target;
      return {
        status: 409,
        body: {
          error: `A record with that ${fields} already exists.`,
          code: 'UNIQUE_VIOLATION',
        },
      };
    }
    case 'P2003':
      return {
        status: 400,
        body: {
          error: 'Referenced record does not exist.',
          code: 'FOREIGN_KEY_VIOLATION',
        },
      };
    case 'P2025':
      return {
        status: 404,
        body: { error: 'Record not found.', code: 'NOT_FOUND' },
      };
    case 'P2014':
      return {
        status: 400,
        body: {
          error: 'The change would violate a required relation.',
          code: 'RELATION_VIOLATION',
        },
      };
    case 'P2021':
    case 'P2022':
      return {
        status: 500,
        body: {
          error: 'A database schema error occurred.',
          code: 'SCHEMA_ERROR',
        },
      };
    default:
      return {
        status: 500,
        body: {
          error: 'A database error occurred.',
          code: 'DATABASE_ERROR',
        },
      };
  }
}

export function errorHandler(
  error: unknown,
  _request: Request,
  response: Response,
  _next: NextFunction,
): void {
  if (response.headersSent) {
    return;
  }

  if (error instanceof HttpError) {
    response.status(error.statusCode).json({
      error: error.message,
      ...(error.code ? { code: error.code } : {}),
    } satisfies ErrorBody);
    return;
  }

  if (error instanceof Prisma.PrismaClientKnownRequestError) {
    const mapped = prismaErrorToHttp(error);
    // Log with context but don't leak internals to the client.
    console.error('[prisma-error]', {
      code: error.code,
      meta: error.meta,
      message: error.message,
    });
    response.status(mapped.status).json(mapped.body);
    return;
  }

  if (error instanceof Prisma.PrismaClientValidationError) {
    console.error('[prisma-validation]', error.message);
    response.status(400).json({
      error: 'Invalid data provided.',
      code: 'VALIDATION_ERROR',
    });
    return;
  }

  if (error instanceof SyntaxError && 'body' in error) {
    // express.json() parse failure
    response.status(400).json({
      error: 'Request body is not valid JSON.',
      code: 'MALFORMED_JSON',
    });
    return;
  }

  console.error('[unhandled-error]', error);
  response.status(500).json({
    error: 'An unexpected server error occurred.',
    code: 'INTERNAL_ERROR',
  });
}