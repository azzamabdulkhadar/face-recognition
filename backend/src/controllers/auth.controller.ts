import type { Request, Response } from 'express';
import { validated } from '../middlewares/validate.js';
import { authUser } from '../middlewares/requireAuth.js';
import { login } from '../services/auth.service.js';
import { setEmployeePassword } from '../services/employee.service.js';
import type { LoginInput } from '../validators/auth.validator.js';
import type { SetPasswordInput } from '../validators/employee.validator.js';

export async function loginController(req: Request, res: Response): Promise<void> {
  const { email, password } = validated<LoginInput>(req, 'body');
  const { token, employee } = await login(email, password);
  res.json({
    success: true,
    token,
    employee: { id: employee.id, name: employee.name, email: employee.email },
  });
}

/** Returns the authenticated employee (used by the app to validate a token). */
export async function me(req: Request, res: Response): Promise<void> {
  const user = authUser(req);
  res.json({
    success: true,
    employee: { id: user.employeeId, name: user.name },
  });
}

/** The logged-in employee sets/changes their own password. */
export async function changePassword(req: Request, res: Response): Promise<void> {
  const user = authUser(req);
  const { password } = validated<SetPasswordInput>(req, 'body');
  await setEmployeePassword(user.employeeId, password);
  res.json({ success: true, message: 'Password updated' });
}
