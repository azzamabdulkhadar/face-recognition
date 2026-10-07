import 'dotenv/config';

function required(name: string, fallback?: string): string {
  const value = process.env[name] ?? fallback;
  if (value === undefined) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

export const env = {
  port: Number(process.env.PORT ?? 5000),
  db: {
    host: required('DB_HOST', 'localhost'),
    port: Number(process.env.DB_PORT ?? 3306),
    user: required('DB_USER', 'root'),
    password: process.env.DB_PASSWORD ?? '',
    database: required('DB_NAME', 'face_recognition_demo'),
  },
  faceMatchThreshold: Number(process.env.FACE_MATCH_THRESHOLD ?? 0.6),
  // Secret used to sign employee login JWTs. Override in production via .env.
  jwtSecret: process.env.JWT_SECRET ?? 'dev-insecure-change-me',
  // How long a login token stays valid.
  jwtExpiresIn: process.env.JWT_EXPIRES_IN ?? '30d',
};
