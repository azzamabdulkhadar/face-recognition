import { z } from 'zod';

// A face embedding: a non-empty array of finite numbers.
const embeddingSchema = z
  .array(z.number().finite('Embedding values must be finite numbers'))
  .min(1, 'Embedding must contain at least one value')
  .max(4096, 'Embedding is too large');

export const registerFaceSchema = z.object({
  employeeId: z.coerce.number().int().positive('employeeId must be a positive integer'),
  embedding: embeddingSchema,
  modelVersion: z.string().trim().min(1).max(50).optional(),
});

export const recognizeFaceSchema = z.object({
  embedding: embeddingSchema,
});

export const faceEmployeeIdParamSchema = z.object({
  employeeId: z.coerce.number().int().positive('employeeId must be a positive integer'),
});

export type RegisterFaceInput = z.infer<typeof registerFaceSchema>;
export type RecognizeFaceInput = z.infer<typeof recognizeFaceSchema>;
