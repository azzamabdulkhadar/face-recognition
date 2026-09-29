-- Face Recognition Demo — database schema
-- Run once against your MySQL server to set up the demo database.

CREATE DATABASE IF NOT EXISTS face_recognition_demo;
USE face_recognition_demo;

CREATE TABLE IF NOT EXISTS employees (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(150) UNIQUE,
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
