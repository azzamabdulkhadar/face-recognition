import { Router } from 'express';
import * as controller from '../controllers/device.controller.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { validate } from '../middlewares/validate.js';
import { requireAuth } from '../middlewares/requireAuth.js';
import {
  deviceIdParamSchema,
  listDevicesQuerySchema,
  registerDeviceSchema,
  rejectDeviceSchema,
  verifyDeviceSchema,
} from '../validators/device.validator.js';

export const deviceRouter = Router();

// ----- Employee self-service (requires login) -----

// Submit / re-submit this device for registration.
deviceRouter.post(
  '/register',
  requireAuth,
  validate(registerDeviceSchema, 'body'),
  asyncHandler(controller.register),
);

// Check this device's trust status (called right after login).
deviceRouter.post(
  '/verify',
  requireAuth,
  validate(verifyDeviceSchema, 'body'),
  asyncHandler(controller.verify),
);

// The logged-in employee's own devices.
deviceRouter.get('/mine', requireAuth, asyncHandler(controller.myDevices));

// ----- Admin management -----
// NOTE: the admin app is trusted on the local network for this demo. In
// production these should sit behind an admin-role check.

deviceRouter.get(
  '/',
  validate(listDevicesQuerySchema, 'query'),
  asyncHandler(controller.list),
);

deviceRouter.get('/audit', asyncHandler(controller.audit));

deviceRouter.post(
  '/:deviceId/approve',
  validate(deviceIdParamSchema, 'params'),
  asyncHandler(controller.approve),
);

deviceRouter.post(
  '/:deviceId/reject',
  validate(deviceIdParamSchema, 'params'),
  validate(rejectDeviceSchema, 'body'),
  asyncHandler(controller.reject),
);

deviceRouter.post(
  '/:deviceId/revoke',
  validate(deviceIdParamSchema, 'params'),
  asyncHandler(controller.revoke),
);

deviceRouter.delete(
  '/:deviceId',
  validate(deviceIdParamSchema, 'params'),
  asyncHandler(controller.remove),
);
