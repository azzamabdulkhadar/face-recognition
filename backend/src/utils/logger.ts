import pino from 'pino';

// Plain pino logger. Add a transport like `pino-pretty` for local dev if desired.
export const logger = pino({
  level: process.env.LOG_LEVEL ?? 'info',
});
