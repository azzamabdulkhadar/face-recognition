import type { NextFunction, Request, Response } from 'express';
import type { ZodType } from 'zod';
import { badRequest } from '../utils/errors.js';

type Source = 'body' | 'params' | 'query';

/**
 * Returns Express middleware that validates the given request source
 * against a Zod schema, replacing it with the parsed (typed) value.
 */
export function validate(schema: ZodType, source: Source = 'body') {
  return (req: Request, _res: Response, next: NextFunction): void => {
    const result = schema.safeParse(req[source]);
    if (!result.success) {
      const message = result.error.issues
        .map((issue) => `${issue.path.join('.') || source}: ${issue.message}`)
        .join('; ');
      next(badRequest(message));
      return;
    }
    // Store the validated value for the controller to consume.
    (req as unknown as Record<string, unknown>)[`validated_${source}`] = result.data;
    next();
  };
}

export function validated<T>(req: Request, source: Source = 'body'): T {
  return (req as unknown as Record<string, unknown>)[`validated_${source}`] as T;
}
