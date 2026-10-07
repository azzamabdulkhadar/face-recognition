import type { ResultSetHeader, RowDataPacket } from 'mysql2';
import bcrypt from 'bcryptjs';
import { pool } from '../config/database.js';
import { conflict, notFound } from '../utils/errors.js';
import type { CreateEmployeeInput } from '../validators/employee.validator.js';

export interface Employee {
  id: number;
  name: string;
  email: string | null;
  created_at: string;
}

/** Internal shape including the password hash; never returned to clients. */
interface EmployeeRow extends Employee {
  password_hash: string | null;
}

const BCRYPT_ROUNDS = 10;

export async function createEmployee(input: CreateEmployeeInput): Promise<Employee> {
  try {
    const passwordHash = input.password
      ? await bcrypt.hash(input.password, BCRYPT_ROUNDS)
      : null;
    const [result] = await pool.execute<ResultSetHeader>(
      'INSERT INTO employees (name, email, password_hash) VALUES (?, ?, ?)',
      [input.name, input.email ?? null, passwordHash],
    );
    return getEmployeeById(result.insertId);
  } catch (err) {
    // MySQL duplicate key on the unique email column.
    if (isDuplicateKeyError(err)) {
      throw conflict('An employee with this email already exists');
    }
    throw err;
  }
}

/** Look up an employee by email, including the password hash (for login). */
export async function findEmployeeByEmail(
  email: string,
): Promise<EmployeeRow | null> {
  const [rows] = await pool.execute<(EmployeeRow & RowDataPacket)[]>(
    'SELECT id, name, email, password_hash, created_at FROM employees WHERE email = ?',
    [email],
  );
  return rows[0] ?? null;
}

/** Set (or replace) an employee's login password. */
export async function setEmployeePassword(
  employeeId: number,
  password: string,
): Promise<void> {
  const employee = await findEmployeeById(employeeId);
  if (!employee) {
    throw notFound(`Employee ${employeeId} not found`);
  }
  const passwordHash = await bcrypt.hash(password, BCRYPT_ROUNDS);
  await pool.execute<ResultSetHeader>(
    'UPDATE employees SET password_hash = ? WHERE id = ?',
    [passwordHash, employeeId],
  );
}

export async function verifyPassword(
  password: string,
  hash: string | null,
): Promise<boolean> {
  if (!hash) return false;
  return bcrypt.compare(password, hash);
}

export async function listEmployees(): Promise<Employee[]> {
  const [rows] = await pool.query<(Employee & RowDataPacket)[]>(
    'SELECT id, name, email, created_at FROM employees ORDER BY id DESC',
  );
  return rows;
}

export async function getEmployeeById(id: number): Promise<Employee> {
  const employee = await findEmployeeById(id);
  if (!employee) {
    throw notFound(`Employee ${id} not found`);
  }
  return employee;
}

export async function findEmployeeById(id: number): Promise<Employee | null> {
  const [rows] = await pool.execute<(Employee & RowDataPacket)[]>(
    'SELECT id, name, email, created_at FROM employees WHERE id = ?',
    [id],
  );
  return rows[0] ?? null;
}

export async function deleteEmployee(id: number): Promise<void> {
  const [result] = await pool.execute<ResultSetHeader>(
    'DELETE FROM employees WHERE id = ?',
    [id],
  );
  if (result.affectedRows === 0) {
    throw notFound(`Employee ${id} not found`);
  }
}

function isDuplicateKeyError(err: unknown): boolean {
  return (
    typeof err === 'object' &&
    err !== null &&
    'code' in err &&
    (err as { code?: string }).code === 'ER_DUP_ENTRY'
  );
}
