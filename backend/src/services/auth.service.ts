import jwt, { type SignOptions } from 'jsonwebtoken';
import { env } from '../config/env.js';
import { unauthorized } from '../utils/errors.js';
import { logger } from '../utils/logger.js';
import {
  findEmployeeByEmail,
  verifyPassword,
  type Employee,
} from './employee.service.js';

export interface AuthTokenPayload {
  employeeId: number;
  name: string;
}

/** Sign a JWT carrying the employee identity. */
export function signToken(employee: Pick<Employee, 'id' | 'name'>): string {
  const payload: AuthTokenPayload = {
    employeeId: employee.id,
    name: employee.name,
  };
  const options = {
    expiresIn: env.jwtExpiresIn as SignOptions['expiresIn'],
  };
  return jwt.sign(payload, env.jwtSecret, options);
}

/** Verify a JWT and return its payload, or throw 401 if invalid/expired. */
export function verifyToken(token: string): AuthTokenPayload {
  try {
    const decoded = jwt.verify(token, env.jwtSecret);
    if (
      typeof decoded === 'object' &&
      decoded !== null &&
      typeof (decoded as AuthTokenPayload).employeeId === 'number'
    ) {
      return decoded as AuthTokenPayload;
    }
    throw unauthorized('Invalid token');
  } catch {
    throw unauthorized('Invalid or expired token');
  }
}

/**
 * Authenticate an employee by email + password. Returns a signed token and the
 * public employee fields. Throws 401 on any mismatch (without revealing which
 * part failed).
 */
export async function login(
  email: string,
  password: string,
): Promise<{ token: string; employee: Employee }> {
  const row = await findEmployeeByEmail(email);
  if (!row) {
    logger.warn({ email }, 'Login failed: no employee with that email');
    throw unauthorized('Invalid email or password');
  }
  if (!row.password_hash) {
    logger.warn(
      { employeeId: row.id, email },
      'Login failed: employee has no password set',
    );
    throw unauthorized('Invalid email or password');
  }
  const ok = await verifyPassword(password, row.password_hash);
  if (!ok) {
    logger.warn({ employeeId: row.id, email }, 'Login failed: wrong password');
    throw unauthorized('Invalid email or password');
  }
  logger.info({ employeeId: row.id, email }, 'Login succeeded');
  const employee: Employee = {
    id: row.id,
    name: row.name,
    email: row.email,
    created_at: row.created_at,
  };
  return { token: signToken(employee), employee };
}
