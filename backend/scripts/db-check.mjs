// One-off diagnostic: inspect the database the backend is configured to use.
// Run with: node scripts/db-check.mjs
import 'dotenv/config';
import mysql from 'mysql2/promise';

const cfg = {
  host: process.env.DB_HOST ?? 'localhost',
  port: Number(process.env.DB_PORT ?? 3306),
  user: process.env.DB_USER ?? 'root',
  password: process.env.DB_PASSWORD ?? '',
  database: process.env.DB_NAME ?? 'face_recognition_demo',
};

console.log('Connecting with:', {
  ...cfg,
  password: cfg.password ? '***set***' : '(empty)',
});

const EXPECTED_TABLES = [
  'employees',
  'employee_faces',
  'attendance_events',
  'employee_devices',
  'device_audit_logs',
];

let conn;
try {
  conn = await mysql.createConnection(cfg);
  console.log('\n✅ Connected to MySQL.\n');
} catch (err) {
  console.error('\n❌ Could NOT connect to MySQL:', err.code, err.message);
  console.error(
    'Check that MySQL is running and the DB_* values in backend/.env are correct.',
  );
  process.exit(1);
}

try {
  // Does the database exist / which tables are present?
  const [tables] = await conn.query('SHOW TABLES');
  const tableNames = tables.map((r) => Object.values(r)[0]);
  console.log('Tables present:', tableNames.length ? tableNames : '(none)');

  for (const t of EXPECTED_TABLES) {
    const exists = tableNames.includes(t);
    console.log(`  ${exists ? '✓' : '✗ MISSING'}  ${t}`);
  }

  // employees columns (is password_hash there?)
  if (tableNames.includes('employees')) {
    const [cols] = await conn.query('SHOW COLUMNS FROM employees');
    console.log(
      '\nemployees columns:',
      cols.map((c) => c.Field).join(', '),
    );
    const hasPw = cols.some((c) => c.Field === 'password_hash');
    console.log(`  password_hash present: ${hasPw ? 'yes' : 'NO — login/register will 500'}`);
  }

  // Row counts for everything that exists.
  console.log('\nRow counts:');
  for (const t of EXPECTED_TABLES) {
    if (!tableNames.includes(t)) continue;
    const [[{ n }]] = await conn.query(`SELECT COUNT(*) AS n FROM \`${t}\``);
    console.log(`  ${t}: ${n}`);
  }

  // Sample of employees (no secrets echoed).
  if (tableNames.includes('employees')) {
    const [rows] = await conn.query(
      'SELECT id, name, email, (password_hash IS NOT NULL) AS has_password FROM employees ORDER BY id LIMIT 10',
    );
    console.log('\nEmployees (first 10):');
    for (const r of rows) {
      console.log(
        `  #${r.id} ${r.name} <${r.email ?? 'no-email'}> password:${r.has_password ? 'set' : 'none'}`,
      );
    }
  }

  // Sample devices.
  if (tableNames.includes('employee_devices')) {
    const [rows] = await conn.query(
      'SELECT id, employee_id, status, device_registration_id FROM employee_devices ORDER BY id DESC LIMIT 10',
    );
    console.log('\nDevices (latest 10):');
    for (const r of rows) {
      console.log(`  #${r.id} emp:${r.employee_id} ${r.status} ${r.device_registration_id}`);
    }
  }
} catch (err) {
  console.error('\n❌ Query failed:', err.code, err.message);
} finally {
  await conn.end();
}
