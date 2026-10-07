import { Router } from 'express';
import * as controller from '../controllers/auth.controller.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { validate } from '../middlewares/validate.js';
import { requireAuth } from '../middlewares/requireAuth.js';
import { loginSchema } from '../validators/auth.validator.js';
import { setPasswordSchema } from '../validators/employee.validator.js';

export const authRouter = Router();

// Email + password login -> JWT.
authRouter.post(
  '/login',
  validate(loginSchema, 'body'),
  asyncHandler(controller.loginController),
);

// Validate the current token and return the employee.
authRouter.get('/me', requireAuth, asyncHandler(controller.me));

// Logged-in employee sets/changes their own password.
authRouter.post(
  '/password',
  requireAuth,
  validate(setPasswordSchema, 'body'),
  asyncHandler(controller.changePassword),
);
