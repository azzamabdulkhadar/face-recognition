import type { NextFunction, Request, Response } from 'express';
import { unauthorized } from '../utils/errors.js';
import { verifyToken, type AuthTokenPayload } from '../services/auth.service.js';

/**
 * Express middleware that requires a valid employee JWT in the
 * `Authorization: Bearer <token>` header. On success it attaches the decoded
 * payload so controllers can read the authenticated employee id instead of
 * trusting a body/param value.
 */
export function requireAuth(
  req: Request,
  _res: Response,
  next: NextFunction,
): void {
  const header = req.header('authorization') ?? '';
  const match = header.match(/^Bearer\s+(.+)$/i);
  if (!match) {
    next(unauthorized('Authentication required'));
    return;
  }
  const payload = verifyToken(match[1].trim());
  (req as unknown as Record<string, unknown>).auth = payload;
  next();
}

/** Read the authenticated employee payload set by [requireAuth]. */
export function authUser(req: Request): AuthTokenPayload {
  return (req as unknown as Record<string, unknown>).auth as AuthTokenPayload;
}
