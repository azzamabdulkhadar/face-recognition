import { z } from 'zod';

const optStr = (max: number) => z.string().trim().max(max).optional();

export const registerDeviceSchema = z.object({
  deviceRegistrationId: z
    .string()
    .trim()
    .min(8, 'deviceRegistrationId is too short')
    .max(100),
  platform: optStr(20),
  deviceModel: optStr(150),
  manufacturer: optStr(150),
  osVersion: optStr(80),
  appVersion: optStr(40),
});

export const verifyDeviceSchema = z.object({
  deviceRegistrationId: z.string().trim().min(8).max(100),
});

export const deviceIdParamSchema = z.object({
  deviceId: z.coerce.number().int().positive('deviceId must be a positive integer'),
});

export const rejectDeviceSchema = z.object({
  reason: z.string().trim().max(255).optional(),
});

export const listDevicesQuerySchema = z.object({
  status: z
    .enum(['PENDING_APPROVAL', 'ACTIVE', 'REJECTED', 'REVOKED'])
    .optional(),
});

export type RegisterDeviceInput = z.infer<typeof registerDeviceSchema>;
export type VerifyDeviceInput = z.infer<typeof verifyDeviceSchema>;
export type RejectDeviceInput = z.infer<typeof rejectDeviceSchema>;
export type ListDevicesQuery = z.infer<typeof listDevicesQuerySchema>;
