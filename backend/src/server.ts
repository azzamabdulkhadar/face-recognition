import { createApp } from './app.js';
import { env } from './config/env.js';
import { verifyDatabaseConnection } from './config/database.js';
import { logger } from './utils/logger.js';

async function start(): Promise<void> {
  const app = createApp();

  // Try to verify the DB connection, but don't block startup if MySQL
  // isn't running yet — this is a learning demo.
  try {
    await verifyDatabaseConnection();
    logger.info('Database connection verified');
  } catch (err) {
    logger.warn(
      { err: err instanceof Error ? err.message : err },
      'Could not verify database connection; the server will still start. ' +
        'Check your .env DB settings and that MySQL is running.',
    );
  }

  app.listen(env.port, () => {
    logger.info(`Server listening on http://localhost:${env.port}`);
  });
}

start().catch((err) => {
  logger.error({ err }, 'Failed to start server');
  process.exit(1);
});
