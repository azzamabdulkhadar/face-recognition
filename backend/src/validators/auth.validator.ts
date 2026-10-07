import { z } from 'zod';

export const loginSchema = z.object({
  email: z.string().trim().email('Invalid email').max(150),
  password: z.string().min(1, 'Password is required').max(100),
});

export type LoginInput = z.infer<typeof loginSchema>;
