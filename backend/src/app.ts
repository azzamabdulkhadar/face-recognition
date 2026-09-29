import cors from 'cors';
import express from 'express';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import { pinoHttp } from 'pino-http';
import { logger } from './utils/logger.js';
import { employeeRouter } from './routes/employee.routes.js';
import { faceRouter } from './routes/face.routes.js';
import { attendanceRouter } from './routes/attendance.routes.js';
import { errorHandler, notFoundHandler } from './middlewares/errorHandler.js';

export function createApp() {
  const app = express();

  // Security headers and request logging.
  app.use(helmet());
  app.use(pinoHttp({ logger }));

  // Body parsing + CORS. Embeddings can be large, so raise the JSON limit.
  app.use(express.json({ limit: '2mb' }));
  app.use(cors());

  // Basic rate limiting for the demo.
  app.use(
    rateLimit({
      windowMs: 60 * 1000,
      limit: 120,
      standardHeaders: true,
      legacyHeaders: false,
    }),
  );

  // Health check.
  app.get('/health', (_req, res) => {
    res.json({ status: 'ok' });
  });

  // Feature routes.
  app.use('/api/employees', employeeRouter);
  app.use('/api/faces', faceRouter);
  app.use('/api/attendance', attendanceRouter);

  // 404 + centralized error handling (must be last).
  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}
