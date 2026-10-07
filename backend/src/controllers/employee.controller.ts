import type { Request, Response } from 'express';
import { validated } from '../middlewares/validate.js';
import {
  createEmployee,
  deleteEmployee,
  getEmployeeById,
  listEmployees,
  setEmployeePassword,
} from '../services/employee.service.js';
import type {
  CreateEmployeeInput,
  SetPasswordInput,
} from '../validators/employee.validator.js';

export async function create(req: Request, res: Response): Promise<void> {
  const input = validated<CreateEmployeeInput>(req, 'body');
  const employee = await createEmployee(input);
  res.status(201).json({ success: true, employee });
}

export async function list(_req: Request, res: Response): Promise<void> {
  const employees = await listEmployees();
  res.json({ success: true, employees });
}

export async function getOne(req: Request, res: Response): Promise<void> {
  const { id } = validated<{ id: number }>(req, 'params');
  const employee = await getEmployeeById(id);
  res.json({ success: true, employee });
}

export async function remove(req: Request, res: Response): Promise<void> {
  const { id } = validated<{ id: number }>(req, 'params');
  await deleteEmployee(id);
  res.json({ success: true, message: `Employee ${id} deleted` });
}

/** Admin sets or resets an employee's login password. */
export async function setPassword(req: Request, res: Response): Promise<void> {
  const { id } = validated<{ id: number }>(req, 'params');
  const { password } = validated<SetPasswordInput>(req, 'body');
  await setEmployeePassword(id, password);
  res.json({ success: true, message: `Password set for employee ${id}` });
}
