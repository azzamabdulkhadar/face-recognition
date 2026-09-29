import { Router } from 'express';
import * as controller from '../controllers/attendance.controller.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { validate } from '../middlewares/validate.js';
import {
  attendanceEmployeeIdParamSchema,
  listAttendanceQuerySchema,
  recordAttendanceSchema,
} from '../validators/attendance.validator.js';

export const attendanceRouter = Router();

// Verify a face and record a check-in / check-out.
attendanceRouter.post(
  '/',
  validate(recordAttendanceSchema, 'body'),
  asyncHandler(controller.record),
);

// Recent attendance events (optionally ?employeeId= & ?limit=).
attendanceRouter.get(
  '/',
  validate(listAttendanceQuerySchema, 'query'),
  asyncHandler(controller.list),
);

// Current check-in status for an employee.
attendanceRouter.get(
  '/:employeeId/status',
  validate(attendanceEmployeeIdParamSchema, 'params'),
  asyncHandler(controller.status),
);
