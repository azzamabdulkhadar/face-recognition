import { z } from 'zod';

export const createEmployeeSchema = z.object({
  name: z.string().trim().min(1, 'Name is required').max(100),
  email: z.string().trim().email('Invalid email').max(150).optional(),
  // Optional initial login password set by the admin at creation time.
  password: z.string().min(6, 'Password must be at least 6 characters').max(100).optional(),
});

export const employeeIdParamSchema = z.object({
  id: z.coerce.number().int().positive('Employee id must be a positive integer'),
});

export const setPasswordSchema = z.object({
  password: z.string().min(6, 'Password must be at least 6 characters').max(100),
});

export type CreateEmployeeInput = z.infer<typeof createEmployeeSchema>;
export type SetPasswordInput = z.infer<typeof setPasswordSchema>;
