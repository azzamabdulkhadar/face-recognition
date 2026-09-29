import { Router } from 'express';
import * as controller from '../controllers/employee.controller.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { validate } from '../middlewares/validate.js';
import {
  createEmployeeSchema,
  employeeIdParamSchema,
} from '../validators/employee.validator.js';

export const employeeRouter = Router();

employeeRouter.post(
  '/',
  validate(createEmployeeSchema, 'body'),
  asyncHandler(controller.create),
);

employeeRouter.get('/', asyncHandler(controller.list));

employeeRouter.get(
  '/:id',
  validate(employeeIdParamSchema, 'params'),
  asyncHandler(controller.getOne),
);

employeeRouter.delete(
  '/:id',
  validate(employeeIdParamSchema, 'params'),
  asyncHandler(controller.remove),
);
