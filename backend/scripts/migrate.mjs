// Idempotent migration: brings an existing database up to date with the
// device-registration + login feature. Safe to run multiple times.
// Run with: node scripts/migrate.mjs
import 'dotenv/config';
import mysql from 'mysql2/promise';

const cfg = {
  host: process.env.DB_HOST ?? 'localhost',
  port: Number(process.env.DB_PORT ?? 3306),
  user: process.env.DB_USER ?? 'root',
  password: process.env.DB_PASSWORD ?? '',
  database: process.env.DB_NAME ?? 'face_recognition_demo',
  multipleStatements: true,
};

const conn = await mysql.createConnection(cfg);
console.log(`Connected to ${cfg.database} on ${cfg.host}:${cfg.port}`);

async function columnExists(table, column) {
  const [rows] = await conn.query(
    `SELECT COUNT(*) AS n FROM information_schema.COLUMNS
      WHERE TABLE_SCHEMA = ? AND TABLE_NAME = ? AND COLUMN_NAME = ?`,
    [cfg.database, table, column],
  );
  return rows[0].n > 0;
}

try {
  // 1) employees.password_hash
  if (await columnExists('employees', 'password_hash')) {
    console.log('• employees.password_hash already exists — skip');
  } else {
    await conn.query(
      `ALTER TABLE employees
         ADD COLUMN password_hash VARCHAR(100) NULL AFTER email`,
    );
    console.log('✓ Added employees.password_hash');
  }

  // 2) employee_devices
  await conn.query(`
    CREATE TABLE IF NOT EXISTS employee_devices (
      id INT AUTO_INCREMENT PRIMARY KEY,
      employee_id INT NOT NULL,
      device_registration_id VARCHAR(100) NOT NULL,
      platform VARCHAR(20) NULL,
      device_model VARCHAR(150) NULL,
      manufacturer VARCHAR(150) NULL,
      os_version VARCHAR(80) NULL,
      app_version VARCHAR(40) NULL,
      status ENUM('PENDING_APPROVAL','ACTIVE','REJECTED','REVOKED')
        NOT NULL DEFAULT 'PENDING_APPROVAL',
      rejection_reason VARCHAR(255) NULL,
      registered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      approved_at TIMESTAMP NULL,
      rejected_at TIMESTAMP NULL,
      revoked_at TIMESTAMP NULL,
      last_used_at TIMESTAMP NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      CONSTRAINT uq_employee_device UNIQUE (employee_id, device_registration_id),
      CONSTRAINT fk_device_employee FOREIGN KEY (employee_id)
        REFERENCES employees(id) ON DELETE CASCADE
    )`);
  console.log('✓ employee_devices ready');

  // Index (ignore "duplicate key name" if re-run).
  try {
    await conn.query(
      `CREATE INDEX idx_device_employee_status ON employee_devices (employee_id, status)`,
    );
    console.log('✓ Added idx_device_employee_status');
  } catch (e) {
    if (e.code === 'ER_DUP_KEYNAME') console.log('• idx_device_employee_status exists — skip');
    else throw e;
  }

  // 3) device_audit_logs
  await conn.query(`
    CREATE TABLE IF NOT EXISTS device_audit_logs (
      id INT AUTO_INCREMENT PRIMARY KEY,
      device_id INT NULL,
      employee_id INT NULL,
      action VARCHAR(40) NOT NULL,
      performed_by VARCHAR(80) NOT NULL DEFAULT 'system',
      metadata VARCHAR(500) NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )`);
  console.log('✓ device_audit_logs ready');

  try {
    await conn.query(
      `CREATE INDEX idx_device_audit_device ON device_audit_logs (device_id, created_at)`,
    );
    console.log('✓ Added idx_device_audit_device');
  } catch (e) {
    if (e.code === 'ER_DUP_KEYNAME') console.log('• idx_device_audit_device exists — skip');
    else throw e;
  }

  console.log('\n✅ Migration complete.');
} catch (err) {
  console.error('\n❌ Migration failed:', err.code, err.message);
  process.exitCode = 1;
} finally {
  await conn.end();
}
