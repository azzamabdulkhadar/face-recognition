import type { ResultSetHeader, RowDataPacket } from 'mysql2';
import { pool } from '../config/database.js';
import { conflict, unauthorized } from '../utils/errors.js';
import { recognizeFace } from './face.service.js';

export type EventType = 'check_in' | 'check_out';

export interface AttendanceEvent {
  id: number;
  employee_id: number;
  event_type: EventType;
  similarity: number | null;
  created_at: string;
}

export interface AttendanceRecord {
  matched: true;
  event: EventType;
  employee: { id: number; name: string };
  similarity?: number;
  recordedAt: string;
}

interface RecordAttendanceParams {
  embedding: number[];
  event: EventType;
}

/**
 * Verify a face by its embedding, then record a check-in / check-out event.
 *
 * Recognition reuses the same cosine-similarity matching as /faces/recognize.
 * If no registered face clears the threshold, the caller is not authenticated
 * and no event is stored. When matched, we enforce a sensible order so an
 * employee cannot check in twice in a row or check out without checking in.
 */
export async function recordAttendance(
  params: RecordAttendanceParams,
): Promise<AttendanceRecord> {
  const recognition = await recognizeFace(params.embedding);
  if (!recognition.matched || !recognition.employee) {
    throw unauthorized('Face not recognized. Attendance not recorded.');
  }

  const employeeId = recognition.employee.id;
  const last = await getLastEvent(employeeId);

  if (params.event === 'check_in' && last?.event_type === 'check_in') {
    throw conflict(`${recognition.employee.name} is already checked in`);
  }
  if (params.event === 'check_out' && last?.event_type !== 'check_in') {
    throw conflict(`${recognition.employee.name} is not currently checked in`);
  }

  const similarity = recognition.similarity ?? null;
  const [result] = await pool.execute<ResultSetHeader>(
    'INSERT INTO attendance_events (employee_id, event_type, similarity) VALUES (?, ?, ?)',
    [employeeId, params.event, similarity],
  );

  const created = await getEventById(result.insertId);
  if (!created) {
    throw new Error('Failed to load the attendance event that was just recorded');
  }

  return {
    matched: true,
    event: params.event,
    employee: recognition.employee,
    similarity: recognition.similarity,
    recordedAt: created.created_at,
  };
}

/** Current attendance state for an employee (checked in or out). */
export async function getStatus(
  employeeId: number,
): Promise<{ employeeId: number; status: 'checked_in' | 'checked_out'; since: string | null }> {
  const last = await getLastEvent(employeeId);
  return {
    employeeId,
    status: last?.event_type === 'check_in' ? 'checked_in' : 'checked_out',
    since: last?.created_at ?? null,
  };
}

/** Recent attendance events, newest first. Optionally filtered by employee. */
export async function listEvents(
  options: { employeeId?: number; limit?: number } = {},
): Promise<AttendanceEvent[]> {
  // Clamp + coerce to a safe integer. mysql2 prepared statements reject a bound
  // parameter for LIMIT, so we inline this already-validated integer.
  const limit = Math.trunc(Math.min(Math.max(options.limit ?? 50, 1), 200));
  if (options.employeeId !== undefined) {
    const [rows] = await pool.query<RowDataPacket[]>(
      `SELECT id, employee_id, event_type, similarity, created_at
         FROM attendance_events
        WHERE employee_id = ?
        ORDER BY created_at DESC, id DESC
        LIMIT ${limit}`,
      [options.employeeId],
    );
    return rows.map(toEvent);
  }
  const [rows] = await pool.query<RowDataPacket[]>(
    `SELECT id, employee_id, event_type, similarity, created_at
       FROM attendance_events
      ORDER BY created_at DESC, id DESC
      LIMIT ${limit}`,
  );
  return rows.map(toEvent);
}

async function getLastEvent(employeeId: number): Promise<AttendanceEvent | null> {
  const [rows] = await pool.execute<RowDataPacket[]>(
    `SELECT id, employee_id, event_type, similarity, created_at
       FROM attendance_events
      WHERE employee_id = ?
      ORDER BY created_at DESC, id DESC
      LIMIT 1`,
    [employeeId],
  );
  const row = rows[0];
  return row ? toEvent(row) : null;
}

async function getEventById(id: number): Promise<AttendanceEvent | null> {
  const [rows] = await pool.execute<RowDataPacket[]>(
    `SELECT id, employee_id, event_type, similarity, created_at
       FROM attendance_events
      WHERE id = ?`,
    [id],
  );
  const row = rows[0];
  return row ? toEvent(row) : null;
}

function toEvent(row: RowDataPacket): AttendanceEvent {
  return {
    id: row.id,
    employee_id: row.employee_id,
    event_type: row.event_type as EventType,
    similarity: row.similarity === null ? null : Number(row.similarity),
    created_at: row.created_at,
  };
}
