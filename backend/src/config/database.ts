import mysql from 'mysql2/promise';
import { env } from './env.js';

// A single shared connection pool, initialized once when the backend starts.
export const pool = mysql.createPool({
  host: env.db.host,
  port: env.db.port,
  user: env.db.user,
  password: env.db.password,
  database: env.db.database,
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
});

/**
 * Verify the database is reachable. Called at startup so we fail fast
 * with a clear message instead of on the first request.
 */
export async function verifyDatabaseConnection(): Promise<void> {
  const connection = await pool.getConnection();
  try {
    await connection.ping();
  } finally {
    connection.release();
  }
}
