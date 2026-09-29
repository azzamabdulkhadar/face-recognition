import type { ResultSetHeader, RowDataPacket } from 'mysql2';
import { pool } from '../config/database.js';
import { env } from '../config/env.js';
import { badRequest, conflict, notFound } from '../utils/errors.js';
import { findEmployeeById } from './employee.service.js';

export interface EmployeeFace {
  id: number;
  employee_id: number;
  embedding: number[];
  model_version: string;
  created_at: string;
  updated_at: string;
}

interface RegisterFaceParams {
  employeeId: number;
  embedding: number[];
  modelVersion?: string;
}

export interface RecognitionResult {
  matched: boolean;
  employee?: { id: number; name: string };
  similarity?: number;
}

/**
 * Cosine similarity between two equal-length vectors.
 * Returns a value in [-1, 1]; higher means more similar.
 */
export function cosineSimilarity(a: number[], b: number[]): number {
  if (a.length !== b.length) {
    throw badRequest('Embeddings have different dimensions');
  }
  let dot = 0;
  let magA = 0;
  let magB = 0;
  for (let i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    magA += a[i] * a[i];
    magB += b[i] * b[i];
  }
  const denom = Math.sqrt(magA) * Math.sqrt(magB);
  if (denom === 0) {
    return 0;
  }
  return dot / denom;
}

/** Register a face embedding for an employee (one face per employee). */
export async function registerFace(params: RegisterFaceParams): Promise<EmployeeFace> {
  const employee = await findEmployeeById(params.employeeId);
  if (!employee) {
    throw notFound(`Employee ${params.employeeId} not found`);
  }

  const existing = await getEmployeeFace(params.employeeId);
  if (existing) {
    throw conflict('Employee already has a registered face');
  }

  const modelVersion = params.modelVersion ?? 'v1';
  await pool.execute<ResultSetHeader>(
    'INSERT INTO employee_faces (employee_id, embedding, model_version) VALUES (?, CAST(? AS JSON), ?)',
    [params.employeeId, JSON.stringify(params.embedding), modelVersion],
  );

  const created = await getEmployeeFace(params.employeeId);
  if (!created) {
    // Should not happen, but keep the return type honest.
    throw new Error('Failed to load the face that was just registered');
  }
  return created;
}

export async function getEmployeeFace(employeeId: number): Promise<EmployeeFace | null> {
  const [rows] = await pool.execute<RowDataPacket[]>(
    'SELECT id, employee_id, embedding, model_version, created_at, updated_at FROM employee_faces WHERE employee_id = ?',
    [employeeId],
  );
  const row = rows[0];
  if (!row) {
    return null;
  }
  return { ...row, embedding: parseEmbedding(row.embedding) } as EmployeeFace;
}

export async function deleteEmployeeFace(employeeId: number): Promise<void> {
  const [result] = await pool.execute<ResultSetHeader>(
    'DELETE FROM employee_faces WHERE employee_id = ?',
    [employeeId],
  );
  if (result.affectedRows === 0) {
    throw notFound(`No registered face for employee ${employeeId}`);
  }
}

/**
 * Compare an incoming embedding against every registered face and return
 * the best match if it clears the configured similarity threshold.
 */
export async function recognizeFace(embedding: number[]): Promise<RecognitionResult> {
  const [rows] = await pool.query<RowDataPacket[]>(
    `SELECT f.employee_id, f.embedding, e.name
       FROM employee_faces f
       JOIN employees e ON e.id = f.employee_id`,
  );

  let best: { employeeId: number; name: string; similarity: number } | null = null;

  for (const row of rows) {
    const stored = parseEmbedding(row.embedding);
    if (stored.length !== embedding.length) {
      // Skip templates from a different model / dimensionality.
      continue;
    }
    const similarity = cosineSimilarity(embedding, stored);
    if (!best || similarity > best.similarity) {
      best = { employeeId: row.employee_id, name: row.name, similarity };
    }
  }

  if (!best || best.similarity < env.faceMatchThreshold) {
    return { matched: false };
  }

  return {
    matched: true,
    employee: { id: best.employeeId, name: best.name },
    similarity: Number(best.similarity.toFixed(4)),
  };
}

/** mysql2 may return JSON columns already parsed or as a string. */
function parseEmbedding(value: unknown): number[] {
  if (Array.isArray(value)) {
    return value as number[];
  }
  if (typeof value === 'string') {
    return JSON.parse(value) as number[];
  }
  throw new Error('Stored embedding is not a valid JSON array');
}
