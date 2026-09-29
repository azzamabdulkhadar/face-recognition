# Face Recognition Attendance System

A demo employee attendance system built around **on-device face recognition**. A Flutter mobile/desktop app captures a face, runs face detection and generates a face embedding locally, then talks to a Node.js + TypeScript backend that stores embeddings in MySQL and decides who the person is by comparing embeddings.

The core idea: face recognition is **not** "does photo A equal photo B". It is:

```
Face → Embedding (numeric vector) → Similarity/distance → Identity decision
```

---

## Table of Contents

- [Problem We Solve](#problem-we-solve)
- [Project Introduction](#project-introduction)
- [Tech Stack](#tech-stack)
- [Architecture](#architecture)
- [Folder Structure](#folder-structure)
- [API Reference](#api-reference)
- [How to Run](#how-to-run)
- [Project Scope](#project-scope)
- [Security Notes](#security-notes)
- [Future Plans](#future-plans)
- [Conclusion](#conclusion)

---

## Problem We Solve

Traditional attendance methods (paper registers, ID cards, PINs, fingerprint pads) are slow, easy to fake through buddy-punching, and require shared hardware. This project explores a contactless alternative: an employee's identity is verified from their face, and attendance is recorded automatically.

Just as important, this repository is a **learning project** that builds the face-recognition pipeline from first principles — detection, embedding generation, similarity comparison and threshold tuning — so the mechanics are understood before layering on production concerns like liveness detection and encrypted biometric storage.

---

## Project Introduction

The system has three parts:

- **`employees/`** — a Flutter client (Android, iOS, web, desktop) that owns the camera, on-device face detection (Google ML Kit), and on-device face embedding (MobileFaceNet via TFLite). It never uploads raw camera frames for ordinary recognition — only the resulting embedding vector.
- **`backend/`** — a Node.js + TypeScript + Express REST API that manages employees, stores one face embedding per employee, recognizes incoming embeddings by cosine similarity, and records attendance check-in / check-out events. Data lives in MySQL.
- **`admin/`** — a placeholder for a future admin surface (enrollment approval, reporting).

Face processing happens on the device. The backend receives a numeric embedding, compares it against registered embeddings, and returns the best match above a configurable similarity threshold.

---

## Tech Stack

### Backend (`backend/`)
- **Node.js** + **TypeScript** (ESM)
- **Express 5** — HTTP/REST framework
- **MySQL** via **mysql2** (connection pool)
- **Zod** — request validation
- **Helmet** — security headers
- **express-rate-limit** — basic rate limiting
- **pino** / **pino-http** — structured logging
- **dotenv** — environment configuration
- **tsx** — TypeScript dev runner / watch mode

### Client (`employees/`)
- **Flutter** / **Dart** (SDK ^3.11)
- **camera** — live preview and frame capture
- **google_mlkit_face_detection** — on-device face detection, landmarks, head angles
- **tflite_flutter** — runs the MobileFaceNet embedding model
- **image** — decode/crop/resize the 112×112 face crop the model expects
- **permission_handler** — camera permission
- **http** — backend API calls

### Tooling
- VS Code, Postman (API testing), MySQL Workbench, Git

---

## Architecture

```
                        FLUTTER CLIENT (employees/)
                                 |
                  +--------------+--------------+
                  |                             |
               Camera                    Face Detection (ML Kit)
                  |                             |
                  +--------------+--------------+
                                 |
                     Face Embedding (MobileFaceNet / TFLite)
                                 |
                        embedding vector (JSON)
                                 |  HTTP
                                 v
                     NODE + EXPRESS API (backend/)
                                 |
              +------------------+------------------+
              |                  |                  |
              v                  v                  v
      Employee Service     Face Service     Attendance Service
              |                  |                  |
              +------------------+------------------+
                                 |
                              MySQL
                    (employees, employee_faces,
                        attendance_events)
                                 |
                                 v
                    Recognition / attendance result
                                 |
                                 v
                            Flutter UI
```

Request path on the backend is layered:

```
Route → Zod validation middleware → Controller → Service → MySQL
```

Errors flow through a centralized error handler; a `/health` endpoint is provided for readiness checks.

---

## Folder Structure

```
companyapp/
├── admin/                     # Placeholder for future admin app
├── backend/                   # Node.js + TypeScript + Express API
│   ├── src/
│   │   ├── app.ts             # Express app: middleware + route wiring
│   │   ├── server.ts          # Entry point: load env, start server
│   │   ├── config/
│   │   │   ├── database.ts     # MySQL connection pool
│   │   │   └── env.ts          # Typed environment config
│   │   ├── controllers/        # HTTP request handlers
│   │   │   ├── employee.controller.ts
│   │   │   ├── face.controller.ts
│   │   │   └── attendance.controller.ts
│   │   ├── services/           # Business logic
│   │   │   ├── employee.service.ts
│   │   │   ├── face.service.ts        # embedding storage + cosine similarity
│   │   │   └── attendance.service.ts
│   │   ├── routes/             # Route definitions
│   │   ├── validators/         # Zod schemas
│   │   ├── middlewares/        # validate(), errorHandler
│   │   ├── utils/              # asyncHandler, errors, logger
│   │   └── db/
│   │       └── schema.sql      # MySQL schema (run once)
│   ├── .env.example
│   ├── package.json
│   └── tsconfig.json
│
└── employees/                 # Flutter client
    ├── lib/
    │   ├── main.dart
    │   ├── config.dart         # default backend base URL
    │   ├── models/             # employee, face_info, attendance, results
    │   ├── screens/            # home, register_face, recognize, attendance, employees
    │   └── services/           # api_client, face_camera, face_embedder, embedding_generator
    ├── assets/models/          # mobilefacenet.tflite (embedding model)
    └── pubspec.yaml
```

---

## API Reference

Base URL: `http://localhost:5000`

### Health
| Method | Path      | Description        |
|--------|-----------|--------------------|
| GET    | `/health` | Service readiness  |

### Employees
| Method | Path                 | Description             |
|--------|----------------------|-------------------------|
| POST   | `/api/employees`     | Create an employee      |
| GET    | `/api/employees`     | List employees          |
| GET    | `/api/employees/:id` | Get one employee        |
| DELETE | `/api/employees/:id` | Delete an employee      |

### Faces
| Method | Path                      | Description                              |
|--------|---------------------------|------------------------------------------|
| POST   | `/api/faces/register`     | Register an employee's face embedding    |
| POST   | `/api/faces/recognize`    | Recognize a face from an embedding       |
| GET    | `/api/faces/:employeeId`  | Get an employee's stored face            |
| DELETE | `/api/faces/:employeeId`  | Remove an employee's stored face         |

### Attendance
| Method | Path                              | Description                               |
|--------|-----------------------------------|-------------------------------------------|
| POST   | `/api/attendance`                 | Verify a face and record check-in/out     |
| GET    | `/api/attendance`                 | Recent events (`?employeeId=` & `?limit=`)|
| GET    | `/api/attendance/:employeeId/status` | Current check-in status                |

**Example — register a face**
```http
POST /api/faces/register
Content-Type: application/json

{
  "employeeId": 1,
  "embedding": [0.123, -0.456, 0.789, ...]
}
```

**Example — recognize**
```json
// request
{ "embedding": [0.120, -0.450, 0.780, ...] }

// matched response
{ "matched": true, "employee": { "id": 1, "name": "Azzam" }, "similarity": 0.91 }

// no match
{ "matched": false }
```

---

## How to Run

### Prerequisites
- Node.js 18+ and npm
- MySQL server
- Flutter SDK (Dart ^3.11) for the client
- A MobileFaceNet model at `employees/assets/models/mobilefacenet.tflite` (see `assets/models/README.md`)

### 1. Database
Create the schema (from a MySQL client or CLI):
```bash
mysql -u root -p < backend/src/db/schema.sql
```
This creates the `face_recognition_demo` database with `employees`, `employee_faces`, and `attendance_events` tables.

### 2. Backend
```bash
cd backend
npm install
cp .env.example .env      # then edit DB credentials
npm run dev               # start with tsx watch on http://localhost:5000
```
Environment variables (`backend/.env`):
```env
PORT=5000
DB_HOST=localhost
DB_PORT=3306
DB_USER=root
DB_PASSWORD=your_password
DB_NAME=face_recognition_demo
FACE_MATCH_THRESHOLD=0.6   # cosine similarity threshold, tune experimentally
```
Production build:
```bash
npm run build             # tsc → dist/
npm start                 # node dist/server.js
```

> Never commit `.env` — it is already git-ignored.

### 3. Flutter client
```bash
cd employees
flutter pub get
flutter run
```
The client defaults to `http://localhost:5000`, and to `http://10.0.2.2:5000` on the Android emulator (see `lib/config.dart`). Adjust from the in-app settings if your backend runs elsewhere.

### 4. Test the API (optional)
Use Postman to create employees, register embeddings, and verify recognition returns the right match — and that an unknown face returns no match.

---

## Project Scope

**In scope (current demo):**
- Employee CRUD
- One registered face embedding per employee (duplicate registration is rejected)
- Face recognition by cosine similarity against a configurable threshold
- Attendance check-in / check-out events and status lookup
- On-device face detection and embedding generation in the Flutter client
- Basic hardening: Helmet headers, rate limiting, request validation, structured logging

**Intentionally out of scope for now:**
- Production-grade liveness / anti-spoofing
- Encrypted biometric templates and key management
- Authentication, role-based authorization, admin approval flows
- GPS validation, payroll, leave management
- Audit logs, retention/privacy controls, secure deletion

The recognition endpoint accepts an embedding directly because the objective is to learn the pipeline. A production system must additionally establish and authorize the employee's identity server-side.

---

## Security Notes

This is a learning demo, not a production biometric system. Before real-world use, the following are required:

- Encryption at rest for embeddings + key management
- Authentication and role-based authorization
- Liveness / anti-spoofing (tested against printed photos, phone photos, recorded video)
- Admin-approved enrollment and controlled re-registration
- Audit logging, rate limiting, secure deletion, and privacy/retention policies

Embeddings are currently stored as JSON in MySQL purely to keep the learning process simple.

---

## Future Plans

- **Liveness detection** — challenge-response (blink, head turn) using ML Kit landmarks and eye-open probabilities, plus anti-spoofing checks.
- **Face quality gating** — enforce exactly one face, sufficient size, centering, lighting, low blur, and reasonable head angle before generating an embedding.
- **Admin app** — flesh out `admin/` for enrollment approval, employee management, and attendance reports.
- **Secure biometric storage** — encryption at rest, key management, secure deletion.
- **Auth & authorization** — authenticated sessions, role-based access, server-side identity enforcement.
- **Attendance features** — GPS validation, shift rules, richer reporting and exports.
- **Reliability testing** — across lighting, angles, distances, devices, and eyewear.

---

## Conclusion

This project demonstrates a complete, end-to-end face-recognition attendance flow: capture and embedding on the device, recognition and record-keeping on the server. It deliberately keeps the recognition pipeline transparent and simple so the fundamentals are clear, while documenting exactly what must be added — liveness, encryption, authorization, and audit controls — to evolve it into a production-ready employee management system.
