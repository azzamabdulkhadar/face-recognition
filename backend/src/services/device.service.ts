import type { ResultSetHeader, RowDataPacket } from 'mysql2';
import { pool } from '../config/database.js';
import { badRequest, conflict, notFound } from '../utils/errors.js';
import { logger } from '../utils/logger.js';
import { findEmployeeById } from './employee.service.js';

export type DeviceStatus =
  | 'PENDING_APPROVAL'
  | 'ACTIVE'
  | 'REJECTED'
  | 'REVOKED';

export interface EmployeeDevice {
  id: number;
  employee_id: number;
  device_registration_id: string;
  platform: string | null;
  device_model: string | null;
  manufacturer: string | null;
  os_version: string | null;
  app_version: string | null;
  status: DeviceStatus;
  rejection_reason: string | null;
  registered_at: string;
  approved_at: string | null;
  rejected_at: string | null;
  revoked_at: string | null;
  last_used_at: string | null;
  created_at: string;
  updated_at: string;
}

export interface RegisterDeviceParams {
  employeeId: number;
  deviceRegistrationId: string;
  platform?: string | null;
  deviceModel?: string | null;
  manufacturer?: string | null;
  osVersion?: string | null;
  appVersion?: string | null;
}

const DEVICE_COLUMNS = `id, employee_id, device_registration_id, platform,
  device_model, manufacturer, os_version, app_version, status,
  rejection_reason, registered_at, approved_at, rejected_at, revoked_at,
  last_used_at, created_at, updated_at`;

async function audit(
  action: string,
  opts: {
    deviceId?: number | null;
    employeeId?: number | null;
    performedBy?: string;
    metadata?: string | null;
  },
): Promise<void> {
  await pool.execute<ResultSetHeader>(
    `INSERT INTO device_audit_logs (device_id, employee_id, action, performed_by, metadata)
     VALUES (?, ?, ?, ?, ?)`,
    [
      opts.deviceId ?? null,
      opts.employeeId ?? null,
      action,
      opts.performedBy ?? 'system',
      opts.metadata ?? null,
    ],
  );
  logger.info(
    {
      action,
      deviceId: opts.deviceId ?? null,
      employeeId: opts.employeeId ?? null,
      performedBy: opts.performedBy ?? 'system',
    },
    'Device action',
  );
}

function toDevice(row: RowDataPacket): EmployeeDevice {
  return row as EmployeeDevice;
}

/**
 * Employee submits (or re-submits) a device registration request. The device
 * is identified by an app-generated UUID. One row per (employee, device): a
 * repeat registration of the same device resets a rejected/revoked record back
 * to PENDING_APPROVAL rather than duplicating it.
 *
 * Policy: an employee may have only one ACTIVE device. If another device is
 * already ACTIVE, registering a new one is blocked until the old one is revoked.
 */
export async function registerDevice(
  params: RegisterDeviceParams,
): Promise<EmployeeDevice> {
  const employee = await findEmployeeById(params.employeeId);
  if (!employee) {
    throw notFound(`Employee ${params.employeeId} not found`);
  }

  const existing = await findDevice(
    params.employeeId,
    params.deviceRegistrationId,
  );

  // If this exact device is already active or pending, don't duplicate the work.
  if (existing && existing.status === 'ACTIVE') {
    throw conflict('This device is already registered and active');
  }
  if (existing && existing.status === 'PENDING_APPROVAL') {
    throw conflict('This device is already awaiting approval');
  }

  // One active device per employee (on a *different* device id).
  const activeOther = await getActiveDevice(params.employeeId);
  if (activeOther && activeOther.device_registration_id !== params.deviceRegistrationId) {
    throw conflict(
      'You already have an active device. Ask an admin to revoke it before ' +
        'registering a new one.',
    );
  }

  if (existing) {
    // Re-register a previously rejected/revoked device: reset to pending.
    await pool.execute<ResultSetHeader>(
      `UPDATE employee_devices
          SET status = 'PENDING_APPROVAL', platform = ?, device_model = ?,
              manufacturer = ?, os_version = ?, app_version = ?,
              rejection_reason = NULL, registered_at = CURRENT_TIMESTAMP,
              approved_at = NULL, rejected_at = NULL, revoked_at = NULL
        WHERE id = ?`,
      [
        params.platform ?? null,
        params.deviceModel ?? null,
        params.manufacturer ?? null,
        params.osVersion ?? null,
        params.appVersion ?? null,
        existing.id,
      ],
    );
    await audit('RE_REGISTERED', {
      deviceId: existing.id,
      employeeId: params.employeeId,
      performedBy: `employee:${params.employeeId}`,
    });
    return (await getDeviceById(existing.id))!;
  }

  const [result] = await pool.execute<ResultSetHeader>(
    `INSERT INTO employee_devices
       (employee_id, device_registration_id, platform, device_model,
        manufacturer, os_version, app_version)
     VALUES (?, ?, ?, ?, ?, ?, ?)`,
    [
      params.employeeId,
      params.deviceRegistrationId,
      params.platform ?? null,
      params.deviceModel ?? null,
      params.manufacturer ?? null,
      params.osVersion ?? null,
      params.appVersion ?? null,
    ],
  );
  logger.info(
    {
      deviceId: result.insertId,
      employeeId: params.employeeId,
      deviceRegistrationId: params.deviceRegistrationId,
      platform: params.platform,
    },
    'Device registered (new row inserted, PENDING_APPROVAL)',
  );
  await audit('REGISTRATION_COMPLETED', {
    deviceId: result.insertId,
    employeeId: params.employeeId,
    performedBy: `employee:${params.employeeId}`,
  });
  return (await getDeviceById(result.insertId))!;
}

/**
 * The app calls this after login to learn the trust state of the current
 * device. Returns a status the app uses to gate access.
 */
export async function verifyDevice(
  employeeId: number,
  deviceRegistrationId: string,
): Promise<{ status: DeviceStatus | 'NOT_REGISTERED'; device: EmployeeDevice | null }> {
  const device = await findDevice(employeeId, deviceRegistrationId);
  logger.info(
    { employeeId, deviceRegistrationId, status: device?.status ?? 'NOT_REGISTERED' },
    'Device verify',
  );
  if (!device) {
    return { status: 'NOT_REGISTERED', device: null };
  }
  if (device.status === 'ACTIVE') {
    await pool.execute<ResultSetHeader>(
      'UPDATE employee_devices SET last_used_at = CURRENT_TIMESTAMP WHERE id = ?',
      [device.id],
    );
  }
  return { status: device.status, device };
}

export async function listEmployeeDevices(
  employeeId: number,
): Promise<EmployeeDevice[]> {
  const [rows] = await pool.query<RowDataPacket[]>(
    `SELECT ${DEVICE_COLUMNS} FROM employee_devices
      WHERE employee_id = ? ORDER BY id DESC`,
    [employeeId],
  );
  return rows.map(toDevice);
}

/** All devices (admin), optionally filtered by status, with employee names. */
export async function listAllDevices(
  status?: DeviceStatus,
): Promise<(EmployeeDevice & { employee_name: string })[]> {
  const where = status ? 'WHERE d.status = ?' : '';
  const args = status ? [status] : [];
  const [rows] = await pool.query<RowDataPacket[]>(
    `SELECT d.id, d.employee_id, d.device_registration_id, d.platform,
            d.device_model, d.manufacturer, d.os_version, d.app_version,
            d.status, d.rejection_reason, d.registered_at, d.approved_at,
            d.rejected_at, d.revoked_at, d.last_used_at, d.created_at,
            d.updated_at, e.name AS employee_name
       FROM employee_devices d
       JOIN employees e ON e.id = d.employee_id
       ${where}
      ORDER BY d.id DESC`,
    args,
  );
  return rows.map((r) => ({
    ...toDevice(r),
    employee_name: r.employee_name as string,
  }));
}

export async function approveDevice(
  deviceId: number,
  performedBy: string,
): Promise<EmployeeDevice> {
  const device = await getDeviceById(deviceId);
  if (!device) throw notFound(`Device ${deviceId} not found`);
  if (device.status !== 'PENDING_APPROVAL') {
    throw badRequest('Only a pending device can be approved');
  }
  await pool.execute<ResultSetHeader>(
    `UPDATE employee_devices
        SET status = 'ACTIVE', approved_at = CURRENT_TIMESTAMP,
            rejected_at = NULL, revoked_at = NULL, rejection_reason = NULL
      WHERE id = ?`,
    [deviceId],
  );
  await audit('APPROVED', {
    deviceId,
    employeeId: device.employee_id,
    performedBy,
  });
  return (await getDeviceById(deviceId))!;
}

export async function rejectDevice(
  deviceId: number,
  performedBy: string,
  reason?: string | null,
): Promise<EmployeeDevice> {
  const device = await getDeviceById(deviceId);
  if (!device) throw notFound(`Device ${deviceId} not found`);
  if (device.status !== 'PENDING_APPROVAL') {
    throw badRequest('Only a pending device can be rejected');
  }
  await pool.execute<ResultSetHeader>(
    `UPDATE employee_devices
        SET status = 'REJECTED', rejected_at = CURRENT_TIMESTAMP,
            rejection_reason = ?
      WHERE id = ?`,
    [reason ?? null, deviceId],
  );
  await audit('REJECTED', {
    deviceId,
    employeeId: device.employee_id,
    performedBy,
    metadata: reason ?? null,
  });
  return (await getDeviceById(deviceId))!;
}

export async function revokeDevice(
  deviceId: number,
  performedBy: string,
): Promise<EmployeeDevice> {
  const device = await getDeviceById(deviceId);
  if (!device) throw notFound(`Device ${deviceId} not found`);
  if (device.status !== 'ACTIVE') {
    throw badRequest('Only an active device can be revoked');
  }
  await pool.execute<ResultSetHeader>(
    `UPDATE employee_devices
        SET status = 'REVOKED', revoked_at = CURRENT_TIMESTAMP
      WHERE id = ?`,
    [deviceId],
  );
  await audit('REVOKED', {
    deviceId,
    employeeId: device.employee_id,
    performedBy,
  });
  return (await getDeviceById(deviceId))!;
}

export async function deleteDevice(
  deviceId: number,
  performedBy: string,
): Promise<void> {
  const device = await getDeviceById(deviceId);
  if (!device) throw notFound(`Device ${deviceId} not found`);
  await pool.execute<ResultSetHeader>(
    'DELETE FROM employee_devices WHERE id = ?',
    [deviceId],
  );
  await audit('DELETED', {
    deviceId: null,
    employeeId: device.employee_id,
    performedBy,
    metadata: `device ${deviceId} (${device.device_registration_id})`,
  });
}

export interface DeviceAuditLog {
  id: number;
  device_id: number | null;
  employee_id: number | null;
  action: string;
  performed_by: string;
  metadata: string | null;
  created_at: string;
}

export async function listAuditLogs(limit = 100): Promise<DeviceAuditLog[]> {
  const safeLimit = Math.trunc(Math.min(Math.max(limit, 1), 500));
  const [rows] = await pool.query<RowDataPacket[]>(
    `SELECT id, device_id, employee_id, action, performed_by, metadata, created_at
       FROM device_audit_logs
      ORDER BY id DESC
      LIMIT ${safeLimit}`,
  );
  return rows as DeviceAuditLog[];
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

async function findDevice(
  employeeId: number,
  deviceRegistrationId: string,
): Promise<EmployeeDevice | null> {
  const [rows] = await pool.execute<RowDataPacket[]>(
    `SELECT ${DEVICE_COLUMNS} FROM employee_devices
      WHERE employee_id = ? AND device_registration_id = ?`,
    [employeeId, deviceRegistrationId],
  );
  return rows[0] ? toDevice(rows[0]) : null;
}

async function getActiveDevice(
  employeeId: number,
): Promise<EmployeeDevice | null> {
  const [rows] = await pool.execute<RowDataPacket[]>(
    `SELECT ${DEVICE_COLUMNS} FROM employee_devices
      WHERE employee_id = ? AND status = 'ACTIVE' LIMIT 1`,
    [employeeId],
  );
  return rows[0] ? toDevice(rows[0]) : null;
}

async function getDeviceById(id: number): Promise<EmployeeDevice | null> {
  const [rows] = await pool.execute<RowDataPacket[]>(
    `SELECT ${DEVICE_COLUMNS} FROM employee_devices WHERE id = ?`,
    [id],
  );
  return rows[0] ? toDevice(rows[0]) : null;
}
