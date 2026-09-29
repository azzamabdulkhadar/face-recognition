import type { Request, Response } from 'express';
import { validated } from '../middlewares/validate.js';
import {
  getStatus,
  listEvents,
  recordAttendance,
} from '../services/attendance.service.js';
import type {
  ListAttendanceQuery,
  RecordAttendanceInput,
} from '../validators/attendance.validator.js';

export async function record(req: Request, res: Response): Promise<void> {
  const input = validated<RecordAttendanceInput>(req, 'body');
  const result = await recordAttendance(input);
  res.status(201).json({
    success: true,
    message:
      result.event === 'check_in'
        ? `${result.employee.name} checked in`
        : `${result.employee.name} checked out`,
    ...result,
  });
}

export async function status(req: Request, res: Response): Promise<void> {
  const { employeeId } = validated<{ employeeId: number }>(req, 'params');
  const result = await getStatus(employeeId);
  res.json({ success: true, ...result });
}

export async function list(req: Request, res: Response): Promise<void> {
  const query = validated<ListAttendanceQuery>(req, 'query');
  const events = await listEvents({
    employeeId: query.employeeId,
    limit: query.limit,
  });
  res.json({
    success: true,
    events: events.map((e) => ({
      id: e.id,
      employeeId: e.employee_id,
      event: e.event_type,
      similarity: e.similarity,
      recordedAt: e.created_at,
    })),
  });
}
