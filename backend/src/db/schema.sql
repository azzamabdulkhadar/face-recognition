-- Face Recognition Demo — database schema
-- Run once against your MySQL server to set up the demo database.

CREATE DATABASE IF NOT EXISTS face_recognition_demo;
USE face_recognition_demo;

CREATE TABLE IF NOT EXISTS employees (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(150) UNIQUE,
    -- bcrypt hash of the employee's login password. NULL until an admin or the
    -- employee sets one; such accounts cannot log in yet.
    password_hash VARCHAR(100) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS employee_faces (
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

-- Attendance events: each check-in / check-out is recorded as one row.
CREATE TABLE IF NOT EXISTS attendance_events (
    id INT AUTO_INCREMENT PRIMARY KEY,
    employee_id INT NOT NULL,
    event_type ENUM('check_in', 'check_out') NOT NULL,
    similarity DECIMAL(6, 4) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_attendance_employee
        FOREIGN KEY (employee_id)
        REFERENCES employees(id)
        ON DELETE CASCADE
);

CREATE INDEX idx_attendance_employee_time
    ON attendance_events (employee_id, created_at);

-- -----------------------------------------------------------------------------
-- Device registration
-- -----------------------------------------------------------------------------
-- A trusted device for an employee. The app generates a stable UUID
-- (device_registration_id) stored on the device; the backend never stores any
-- biometric data or private keys. A device must be ACTIVE before the employee
-- can use the app's attendance features on it.
--
-- Status lifecycle:
--   PENDING_APPROVAL -> ACTIVE      (admin approves)
--   PENDING_APPROVAL -> REJECTED    (admin rejects)
--   ACTIVE           -> REVOKED     (admin revokes a trusted device)
-- An employee may re-register after REJECTED/REVOKED.
CREATE TABLE IF NOT EXISTS employee_devices (
    id INT AUTO_INCREMENT PRIMARY KEY,
    employee_id INT NOT NULL,
    device_registration_id VARCHAR(100) NOT NULL,
    platform VARCHAR(20) NULL,
    device_model VARCHAR(150) NULL,
    manufacturer VARCHAR(150) NULL,
    os_version VARCHAR(80) NULL,
    app_version VARCHAR(40) NULL,
    status ENUM('PENDING_APPROVAL', 'ACTIVE', 'REJECTED', 'REVOKED')
        NOT NULL DEFAULT 'PENDING_APPROVAL',
    rejection_reason VARCHAR(255) NULL,
    registered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    approved_at TIMESTAMP NULL,
    rejected_at TIMESTAMP NULL,
    revoked_at TIMESTAMP NULL,
    last_used_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    -- One row per (employee, device). Re-registering the same device updates
    -- the existing row rather than creating duplicates.
    CONSTRAINT uq_employee_device UNIQUE (employee_id, device_registration_id),

    CONSTRAINT fk_device_employee
        FOREIGN KEY (employee_id)
        REFERENCES employees(id)
        ON DELETE CASCADE
);

CREATE INDEX idx_device_employee_status
    ON employee_devices (employee_id, status);

-- Audit trail for every meaningful device action.
CREATE TABLE IF NOT EXISTS device_audit_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    device_id INT NULL,
    employee_id INT NULL,
    action VARCHAR(40) NOT NULL,
    performed_by VARCHAR(80) NOT NULL DEFAULT 'system',
    metadata VARCHAR(500) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_device_audit_device
    ON device_audit_logs (device_id, created_at);

-- -----------------------------------------------------------------------------
-- Migration notes for existing databases (safe to run; ignore duplicate errors)
-- -----------------------------------------------------------------------------
-- ALTER TABLE employees ADD COLUMN password_hash VARCHAR(100) NULL AFTER email;
-- (plus the two CREATE TABLE statements above)
