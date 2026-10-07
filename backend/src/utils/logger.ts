import pino from 'pino';

const isProd = process.env.NODE_ENV === 'production';

// In development, pretty-print logs so they're readable in the terminal.
// In production, emit plain JSON (one line per log) for log collectors.
export const logger = pino({
  level: process.env.LOG_LEVEL ?? 'info',
  transport: isProd
    ? undefined
    : {
        target: 'pino-pretty',
        options: {
          colorize: true,
          translateTime: 'SYS:HH:MM:ss',
          ignore: 'pid,hostname',
        },
      },
});
