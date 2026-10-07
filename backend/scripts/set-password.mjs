// Set an employee's login password by email.
// Usage: node scripts/set-password.mjs <email> <password>
import 'dotenv/config';
import mysql from 'mysql2/promise';
import bcrypt from 'bcryptjs';

const [, , email, password] = process.argv;
if (!email || !password) {
  console.error('Usage: node scripts/set-password.mjs <email> <password>');
  process.exit(1);
}

const conn = await mysql.createConnection({
  host: process.env.DB_HOST ?? 'localhost',
  port: Number(process.env.DB_PORT ?? 3306),
  user: process.env.DB_USER ?? 'root',
  password: process.env.DB_PASSWORD ?? '',
  database: process.env.DB_NAME ?? 'face_recognition_demo',
});

try {
  const hash = await bcrypt.hash(password, 10);
  const [res] = await conn.execute(
    'UPDATE employees SET password_hash = ? WHERE email = ?',
    [hash, email],
  );
  if (res.affectedRows === 0) {
    console.error(`No employee with email ${email}`);
    process.exitCode = 1;
  } else {
    console.log(`✓ Password set for ${email}`);
  }
} finally {
  await conn.end();
}
