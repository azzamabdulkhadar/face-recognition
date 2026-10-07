import type { Request, Response } from 'express';
import { validated } from '../middlewares/validate.js';
import { authUser } from '../middlewares/requireAuth.js';
import {
  approveDevice,
  deleteDevice,
  listAllDevices,
  listAuditLogs,
  listEmployeeDevices,
  registerDevice,
  rejectDevice,
  revokeDevice,
  verifyDevice,
  type EmployeeDevice,
} from '../services/device.service.js';
import type {
  ListDevicesQuery,
  RegisterDeviceInput,
  RejectDeviceInput,
  VerifyDeviceInput,
} from '../validators/device.validator.js';

function toJson(d: EmployeeDevice & { employee_name?: string }) {
  return {
    id: d.id,
    employeeId: d.employee_id,
    employeeName: d.employee_name,
    deviceRegistrationId: d.device_registration_id,
    platform: d.platform,
    deviceModel: d.device_model,
    manufacturer: d.manufacturer,
    osVersion: d.os_version,
    appVersion: d.app_version,
    status: d.status,
    rejectionReason: d.rejection_reason,
    registeredAt: d.registered_at,
    approvedAt: d.approved_at,
    rejectedAt: d.rejected_at,
    revokedAt: d.revoked_at,
    lastUsedAt: d.last_used_at,
  };
}

// ----- Employee (authenticated) -----

export async function register(req: Request, res: Response): Promise<void> {
  const user = authUser(req);
  const input = validated<RegisterDeviceInput>(req, 'body');
  const device = await registerDevice({
    employeeId: user.employeeId,
    deviceRegistrationId: input.deviceRegistrationId,
    platform: input.platform ?? null,
    deviceModel: input.deviceModel ?? null,
    manufacturer: input.manufacturer ?? null,
    osVersion: input.osVersion ?? null,
    appVersion: input.appVersion ?? null,
  });
  res.status(201).json({ success: true, device: toJson(device) });
}

export async function verify(req: Request, res: Response): Promise<void> {
  const user = authUser(req);
  const input = validated<VerifyDeviceInput>(req, 'body');
  const result = await verifyDevice(user.employeeId, input.deviceRegistrationId);
  res.json({
    success: true,
    status: result.status,
    device: result.device ? toJson(result.device) : null,
  });
}

export async function myDevices(req: Request, res: Response): Promise<void> {
  const user = authUser(req);
  const devices = await listEmployeeDevices(user.employeeId);
  res.json({ success: true, devices: devices.map(toJson) });
}

// ----- Admin -----

export async function list(req: Request, res: Response): Promise<void> {
  const query = validated<ListDevicesQuery>(req, 'query');
  const devices = await listAllDevices(query.status);
  res.json({ success: true, devices: devices.map(toJson) });
}

export async function approve(req: Request, res: Response): Promise<void> {
  const { deviceId } = validated<{ deviceId: number }>(req, 'params');
  const device = await approveDevice(deviceId, 'admin');
  res.json({ success: true, message: 'Device approved', device: toJson(device) });
}

export async function reject(req: Request, res: Response): Promise<void> {
  const { deviceId } = validated<{ deviceId: number }>(req, 'params');
  const { reason } = validated<RejectDeviceInput>(req, 'body');
  const device = await rejectDevice(deviceId, 'admin', reason ?? null);
  res.json({ success: true, message: 'Device rejected', device: toJson(device) });
}

export async function revoke(req: Request, res: Response): Promise<void> {
  const { deviceId } = validated<{ deviceId: number }>(req, 'params');
  const device = await revokeDevice(deviceId, 'admin');
  res.json({ success: true, message: 'Device revoked', device: toJson(device) });
}

export async function remove(req: Request, res: Response): Promise<void> {
  const { deviceId } = validated<{ deviceId: number }>(req, 'params');
  await deleteDevice(deviceId, 'admin');
  res.json({ success: true, message: `Device ${deviceId} deleted` });
}

export async function audit(_req: Request, res: Response): Promise<void> {
  const logs = await listAuditLogs(100);
  res.json({ success: true, logs });
}
