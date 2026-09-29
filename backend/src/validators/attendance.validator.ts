import { z } from 'zod';

// A face embedding: a non-empty array of finite numbers.
const embeddingSchema = z
  .array(z.number().finite('Embedding values must be finite numbers'))
  .min(1, 'Embedding must contain at least one value')
  .max(4096, 'Embedding is too large');

export const recordAttendanceSchema = z.object({
  embedding: embeddingSchema,
  event: z.enum(['check_in', 'check_out']),
});

export const attendanceEmployeeIdParamSchema = z.object({
  employeeId: z.coerce.number().int().positive('employeeId must be a positive integer'),
});

export const listAttendanceQuerySchema = z.object({
  employeeId: z.coerce.number().int().positive().optional(),
  limit: z.coerce.number().int().positive().max(200).optional(),
});

export type RecordAttendanceInput = z.infer<typeof recordAttendanceSchema>;
export type ListAttendanceQuery = z.infer<typeof listAttendanceQuerySchema>;
