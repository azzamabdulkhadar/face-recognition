import { Router } from 'express';
import * as controller from '../controllers/face.controller.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { validate } from '../middlewares/validate.js';
import {
  faceEmployeeIdParamSchema,
  recognizeFaceSchema,
  registerFaceSchema,
} from '../validators/face.validator.js';

export const faceRouter = Router();

faceRouter.post(
  '/register',
  validate(registerFaceSchema, 'body'),
  asyncHandler(controller.register),
);

faceRouter.post(
  '/recognize',
  validate(recognizeFaceSchema, 'body'),
  asyncHandler(controller.recognize),
);

faceRouter.get(
  '/:employeeId',
  validate(faceEmployeeIdParamSchema, 'params'),
  asyncHandler(controller.getFace),
);

faceRouter.delete(
  '/:employeeId',
  validate(faceEmployeeIdParamSchema, 'params'),
  asyncHandler(controller.removeFace),
);
