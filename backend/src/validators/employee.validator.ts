import { z } from 'zod';

export const createEmployeeSchema = z.object({
  name: z.string().trim().min(1, 'Name is required').max(100),
  email: z.string().trim().email('Invalid email').max(150).optional(),
});

export const employeeIdParamSchema = z.object({
  id: z.coerce.number().int().positive('Employee id must be a positive integer'),
});

export type CreateEmployeeInput = z.infer<typeof createEmployeeSchema>;
