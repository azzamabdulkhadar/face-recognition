# Face Recognition Demo — Backend Implementation Plan

## 1. Purpose

A small practice project to learn the backend side of employee face recognition:

```text
Create Employee
      ↓
Register Face Embedding
      ↓
Store Embedding
      ↓
Send New Face Embedding
      ↓
Compare Against Registered Embeddings
      ↓
Return Matched Employee
```

This demo intentionally excludes attendance, GPS, payroll, leave management, admin roles, and production biometric security.

---

## 2. Technology Stack

### Backend
- Node.js
- TypeScript
- Express.js
- MySQL
- Zod
- dotenv
- CORS

### Development
- VS Code
- Postman
- MySQL / MySQL Workbench
- Git

### Face processing

For this demo, the backend should receive a **face embedding** rather than continuous camera frames.

```text
Flutter
  ↓
Camera
  ↓
Face detection
  ↓
Face embedding model
  ↓
Embedding
  ↓
Backend
```

Select the exact face-embedding model/package after the basic backend is working.

---

## 3. Project Setup

```bash
mkdir face-recognition-demo
cd face-recognition-demo
npm init -y

npm install express cors dotenv mysql2 zod
npm install -D typescript tsx @types/node @types/express

npx tsc --init
```

Development command:

```bash
npx tsx src/server.ts
```

---

## 4. Project Structure

```text
face-recognition-demo/
│
├── src/
│   ├── config/
│   │   └── database.ts
│   ├── controllers/
│   │   ├── employee.controller.ts
│   │   └── face.controller.ts
│   ├── routes/
│   │   ├── employee.routes.ts
│   │   └── face.routes.ts
│   ├── services/
│   │   └── face.service.ts
│   ├── validators/
│   │   ├── employee.validator.ts
│   │   └── face.validator.ts
│   ├── app.ts
│   └── server.ts
├── .env
├── .env.example
├── .gitignore
├── package.json
└── tsconfig.json
```

Keep the first version simple.

---

## 5. Environment Variables

`.env`:

```env
PORT=5000

DB_HOST=localhost
DB_PORT=3306
DB_USER=root
DB_PASSWORD=your_password
DB_NAME=face_recognition_demo
```

`.env.example`:

```env
PORT=5000

DB_HOST=localhost
DB_PORT=3306
DB_USER=
DB_PASSWORD=
DB_NAME=face_recognition_demo
```

`.gitignore`:

```gitignore
node_modules/
.env
dist/
```

Never commit database credentials.

---

## 6. MySQL Database

```sql
CREATE DATABASE face_recognition_demo;

USE face_recognition_demo;
```

### Employees

```sql
CREATE TABLE employees (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(150) UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Employee faces

For the learning demo, JSON is sufficient:

```sql
CREATE TABLE employee_faces (
    id INT AUTO_INCREMENT PRIMARY KEY,
    employee_id INT NOT NULL UNIQUE,
    embedding JSON NOT NULL,
    model_version VARCHAR(50) NOT NULL DEFAULT 'v1',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT fk_employee_face
        FOREIGN KEY (employee_id)
        REFERENCES employees(id)
        ON DELETE CASCADE
);
```

Production should use stronger biometric storage and encryption.

---

## 7. Database Connection

Create:

```text
src/config/database.ts
```

Use a MySQL connection pool.

```text
Express API
    ↓
Database Pool
    ↓
MySQL
```

Initialize the pool once when the backend starts.

---

## 8. Basic Server

`src/app.ts` should:

- Create the Express application.
- Enable JSON parsing.
- Configure CORS.
- Register routes.
- Add error handling.

`src/server.ts` should:

- Load environment variables.
- Start the server.
- Optionally verify the database connection.

---

# 9. Employee API

Build this before face recognition.

### Create

```http
POST /api/employees
```

```json
{
  "name": "Azzam",
  "email": "azzam@example.com"
}
```

### List

```http
GET /api/employees
```

### Get one

```http
GET /api/employees/:id
```

### Delete

```http
DELETE /api/employees/:id
```

---

# 10. Request Validation

Use Zod for:

- Employee name/email.
- Employee ID.
- Face embedding.
- Embedding dimensions.
- Numeric embedding values.

Flow:

```text
Request
  ↓
Zod validation
  ↓
Valid → Controller
Invalid → 400
```

Never blindly accept arbitrary JSON.

---

# 11. Face Registration API

```http
POST /api/faces/register
```

Example:

```json
{
  "employeeId": 1,
  "embedding": [
    0.123,
    -0.456,
    0.789
  ]
}
```

The real embedding will contain many more values depending on the model.

### Backend flow

```text
Request
   ↓
Validate employeeId
   ↓
Check employee exists
   ↓
Validate embedding
   ↓
Check existing face
   ↓
Store embedding
```

---

# 12. Prevent Duplicate Registration

The demo should have:

```text
1 Employee
   |
   +--- 1 registered face
```

If the employee already has a face:

```json
{
  "success": false,
  "message": "Employee already has a registered face"
}
```

Production EMS can later add controlled re-enrollment.

---

# 13. Face Recognition API

```http
POST /api/faces/recognize
```

Request:

```json
{
  "embedding": [
    0.120,
    -0.450,
    0.780
  ]
}
```

Backend:

```text
Incoming embedding
        ↓
Load registered embeddings
        ↓
Calculate similarity/distance
        ↓
Find best match
        ↓
Compare against threshold
       /       /      MATCH  NO MATCH
     |       |
     v       v
 Employee   Reject
```

---

# 14. Face Comparison

Create in `face.service.ts`:

```text
compareEmbeddings(input, registered)
```

Use the distance/similarity method required by the selected model.

For models that use cosine similarity:

```text
cosineSimilarity(A, B)
```

Do not assume all models use the same metric.

---

# 15. Similarity Threshold

Do not choose a production threshold arbitrarily.

For the demo, test:

### Genuine pairs

```text
A registration → A new capture
```

### Impostor pairs

```text
A registration → B new capture
```

Measure:

- False acceptance.
- False rejection.

Then choose an experimental threshold for the selected model.

---

# 16. Recognition Response

Successful:

```json
{
  "matched": true,
  "employee": {
    "id": 1,
    "name": "Azzam"
  },
  "similarity": 0.91
}
```

No match:

```json
{
  "matched": false
}
```

The similarity value is useful for this learning demo. Do not expose detailed security information to ordinary users in the production EMS.

---

# 17. Face Service

`src/services/face.service.ts`

Responsibilities:

```text
registerFace()
getEmployeeFace()
recognizeFace()
compareEmbeddings()
```

Recommended flow:

```text
Route
  ↓
Controller
  ↓
Service
  ↓
Database
```

---

# 18. Routes

### Employee

```text
POST   /api/employees
GET    /api/employees
GET    /api/employees/:id
DELETE /api/employees/:id
```

### Face

```text
POST   /api/faces/register
POST   /api/faces/recognize
GET    /api/faces/:employeeId
DELETE /api/faces/:employeeId
```

---

# 19. Postman Testing

Before Flutter integration, test everything with Postman.

### Test 1
Create Azzam.

### Test 2
Create Rahul.

### Test 3
Register Azzam's real embedding.

### Test 4
Register Rahul's real embedding.

### Test 5
Send a new Azzam embedding → expected Azzam.

### Test 6
Send a new Rahul embedding → expected Rahul.

### Test 7
Send an unknown person's embedding → expected no match.

### Test 8
Send Rahul's embedding and verify it does not match Azzam.

### Test 9
Attempt duplicate registration → expected rejection.

---

# 20. Flutter Integration

After the backend works:

```text
Camera
   ↓
Face Detection
   ↓
Face Embedding Model
   ↓
Embedding
   ↓
HTTP POST
   ↓
Backend
```

Do not upload continuous camera frames for ordinary recognition.

---

# 21. Flutter Registration

```text
Select/create employee
       ↓
Open camera
       ↓
Detect face
       ↓
Capture suitable face
       ↓
Generate embedding
       ↓
POST /api/faces/register
       ↓
Success
```

---

# 22. Flutter Recognition

```text
Open recognition screen
       ↓
Camera
       ↓
Detect face
       ↓
Generate embedding
       ↓
POST /api/faces/recognize
       ↓
Backend comparison
       ↓
Show employee
```

---

# 23. Multiple Faces

Handle:

```text
0 faces
  → Ask user to position face

1 face
  → Continue

2+ faces
  → Reject / ask others to move away
```

This will be important for the future attendance feature.

---

# 24. Face Quality

Before generating an embedding, eventually check:

- Exactly one face.
- Sufficient face size.
- Reasonable centering.
- Acceptable lighting.
- Reasonable head angle.
- Low blur.

These improve recognition reliability.

---

# 25. Liveness

Do not treat the first demo as a production anti-spoofing system.

First learn:

```text
Face → Embedding → Similarity → Identity
```

Then add:

```text
Liveness
    +
Face recognition
```

Test against:

- Printed photo.
- Phone photo.
- Recorded video.
- Real person.

Production EMS must use a properly tested liveness/anti-spoofing approach.

---

# 26. Demo Security vs Production

The demo can use:

```text
embedding JSON
```

to make the learning process easy.

Do not copy this directly into production.

Production should add:

- Encryption at rest.
- Key management.
- Authentication.
- Role-based authorization.
- Admin approval.
- Controlled re-registration.
- Audit logs.
- Rate limiting.
- Secure deletion.
- Privacy/retention controls.
- Liveness/anti-spoofing.

---

# 27. Important Security Rule

Do not trust:

```json
{
  "employeeId": 1,
  "faceMatched": true
}
```

The backend must calculate the recognition result.

For this demo, the recognition endpoint accepts an embedding because the objective is to learn the recognition pipeline.

Production EMS must additionally establish the authenticated employee identity and enforce authorization.

---

# 28. Development Phases

## Phase 1 — Backend setup

- [ ] Create Node.js project.
- [ ] Install dependencies.
- [ ] Configure TypeScript.
- [ ] Configure environment variables.
- [ ] Connect MySQL.
- [ ] Start Express server.

## Phase 2 — Employee module

- [ ] Create employee.
- [ ] List employees.
- [ ] Get employee.
- [ ] Delete employee.
- [ ] Add Zod validation.

## Phase 3 — Face storage

- [ ] Create `employee_faces`.
- [ ] Create registration endpoint.
- [ ] Validate embedding.
- [ ] Prevent duplicate registration.
- [ ] Create delete-face endpoint.

## Phase 4 — Recognition

- [ ] Select embedding model.
- [ ] Implement comparison.
- [ ] Implement similarity/distance.
- [ ] Test threshold.
- [ ] Create recognition endpoint.

## Phase 5 — Postman

- [ ] Register multiple employees.
- [ ] Recognize each employee.
- [ ] Test unknown person.
- [ ] Test wrong person.
- [ ] Test invalid embedding.
- [ ] Test duplicate registration.

## Phase 6 — Flutter

- [ ] Camera.
- [ ] Face detection.
- [ ] Face embedding.
- [ ] Registration screen.
- [ ] Recognition screen.
- [ ] Backend integration.

## Phase 7 — Reliability

- [ ] Different lighting.
- [ ] Different angles.
- [ ] Different distances.
- [ ] Different phones.
- [ ] Glasses.
- [ ] Multiple faces.

## Phase 8 — Production EMS

Only after the demo works:

- [ ] Authentication.
- [ ] Admin approval.
- [ ] Liveness.
- [ ] Encryption.
- [ ] Audit logs.
- [ ] Controlled re-registration.
- [ ] Attendance.
- [ ] GPS.
- [ ] Rate limiting.
- [ ] Privacy controls.

---

# 29. Definition of Done

The backend demo is complete when:

```text
Employee A
   ↓
Register face
   ↓
Embedding stored
```

```text
Employee B
   ↓
Register face
   ↓
Embedding stored
```

Then:

```text
A's new face → Backend → A
B's new face → Backend → B
Unknown face → Backend → No match
A's face → B's template → No match
```

---

# 30. Final Architecture

```text
                    FLUTTER
                       |
                +------+------+
                |             |
             Camera      Face Detection
                |             |
                +------+------+
                       |
                Face Embedding
                       |
                       | HTTPS
                       v
                NODE + EXPRESS
                       |
              +--------+--------+
              |                 |
              v                 v
       Employee Service   Face Service
              |                 |
              v                 v
            MySQL <-------- Embeddings
              |
              +-------------------+
                                  |
                                  v
                         Recognition Result
                                  |
                                  v
                              Flutter UI
```

## Core concept

Face recognition is not:

```text
Photo A == Photo B
```

It is:

```text
Face
  ↓
Embedding
  ↓
Numerical representation
  ↓
Similarity / distance
  ↓
Identity decision
```

Once this demo works, it can be expanded into the production EMS architecture with **admin-controlled enrollment, liveness detection, encrypted biometric templates, backend authorization, GPS validation, and attendance recording**.
