import type { NextFunction, Request, Response } from 'express';
import { HttpError } from '../utils/errors.js';
import { logger } from '../utils/logger.js';

export function notFoundHandler(req: Request, res: Response): void {
  logger.warn({ method: req.method, url: req.originalUrl }, 'Route not found');
  res.status(404).json({ success: false, message: 'Route not found' });
}

/** Pull the useful bits out of an unknown thrown value for logging. */
function describeError(err: unknown): Record<string, unknown> {
  if (err instanceof Error) {
    const e = err as Error & {
      code?: string;
      errno?: number;
      sqlState?: string;
      sqlMessage?: string;
    };
    return {
      name: e.name,
      message: e.message,
      // mysql2 errors carry these — invaluable for diagnosing DB issues.
      code: e.code,
      errno: e.errno,
      sqlState: e.sqlState,
      sqlMessage: e.sqlMessage,
      stack: e.stack,
    };
  }
  return { value: String(err) };
}

// Express recognizes an error handler by its four parameters.
export function errorHandler(
  err: unknown,
  req: Request,
  res: Response,
  _next: NextFunction,
): void {
  if (err instanceof HttpError) {
    // Expected, handled errors (validation, 404, 409, auth): log at warn.
    logger.warn(
      { method: req.method, url: req.originalUrl, status: err.statusCode, message: err.message },
      'Request rejected',
    );
    res.status(err.statusCode).json({ success: false, message: err.message });
    return;
  }

  // Unexpected error — log everything we can so the real cause is visible.
  const details = describeError(err);
  logger.error(
    { method: req.method, url: req.originalUrl, err: details },
    'Unhandled error',
  );

  // In non-production, surface the real message (and SQL code) to speed up
  // debugging. In production, keep the response generic.
  const isProd = process.env.NODE_ENV === 'production';
  const body: Record<string, unknown> = {
    success: false,
    message: 'Internal server error',
  };
  if (!isProd) {
    body.error = (details.sqlMessage as string) ?? (details.message as string);
    if (details.code) body.code = details.code;
  }
  res.status(500).json(body);
}
