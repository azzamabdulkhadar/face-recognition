import type { ResultSetHeader, RowDataPacket } from 'mysql2';
import { pool } from '../config/database.js';
import { conflict, notFound } from '../utils/errors.js';
import type { CreateEmployeeInput } from '../validators/employee.validator.js';

export interface Employee {
  id: number;
  name: string;
  email: string | null;
  created_at: string;
}

export async function createEmployee(input: CreateEmployeeInput): Promise<Employee> {
  try {
    const [result] = await pool.execute<ResultSetHeader>(
      'INSERT INTO employees (name, email) VALUES (?, ?)',
      [input.name, input.email ?? null],
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
