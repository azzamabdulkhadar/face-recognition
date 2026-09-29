import type { Request, Response } from 'express';
import { notFound } from '../utils/errors.js';
import { validated } from '../middlewares/validate.js';
import {
  deleteEmployeeFace,
  getEmployeeFace,
  recognizeFace,
  registerFace,
} from '../services/face.service.js';
import type {
  RecognizeFaceInput,
  RegisterFaceInput,
} from '../validators/face.validator.js';

export async function register(req: Request, res: Response): Promise<void> {
  const input = validated<RegisterFaceInput>(req, 'body');
  const face = await registerFace(input);
  res.status(201).json({
    success: true,
    message: 'Face registered',
    face: {
      id: face.id,
      employeeId: face.employee_id,
      modelVersion: face.model_version,
      dimensions: face.embedding.length,
    },
  });
}

export async function recognize(req: Request, res: Response): Promise<void> {
  const { embedding } = validated<RecognizeFaceInput>(req, 'body');
  const result = await recognizeFace(embedding);
  res.json(result);
}

export async function getFace(req: Request, res: Response): Promise<void> {
  const { employeeId } = validated<{ employeeId: number }>(req, 'params');
  const face = await getEmployeeFace(employeeId);
  if (!face) {
    throw notFound(`No registered face for employee ${employeeId}`);
  }
  res.json({
    success: true,
    face: {
      id: face.id,
      employeeId: face.employee_id,
      modelVersion: face.model_version,
      dimensions: face.embedding.length,
      createdAt: face.created_at,
      updatedAt: face.updated_at,
    },
  });
}

export async function removeFace(req: Request, res: Response): Promise<void> {
  const { employeeId } = validated<{ employeeId: number }>(req, 'params');
  await deleteEmployeeFace(employeeId);
  res.json({ success: true, message: `Face for employee ${employeeId} deleted` });
}
