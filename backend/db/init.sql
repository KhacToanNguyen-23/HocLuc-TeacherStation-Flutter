-- =========================================================
-- Học Lực · Trạm Giảng Dạy (TeacherStation)
-- Script khởi tạo Cơ sở dữ liệu PostgreSQL cho Docker
-- =========================================================

-- Bảng người dùng (Giáo viên / Học sinh)
CREATE TABLE IF NOT EXISTS users (
    id VARCHAR(64) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE,
    phone VARCHAR(20) UNIQUE,
    password_hash VARCHAR(255),
    role VARCHAR(50) DEFAULT 'TEACHER',
    avatar_url TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Bảng phòng học / Phiên giảng dạy (Classroom Sessions)
CREATE TABLE IF NOT EXISTS classrooms (
    id VARCHAR(64) PRIMARY KEY,
    teacher_id VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    meeting_url TEXT NOT NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'ONGOING', -- ONGOING, COMPLETED, SCHEDULED
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ended_at TIMESTAMP,
    duration_minutes INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_classrooms_teacher_status ON classrooms(teacher_id, status);

-- Bảng lưu trữ lịch sử mã OTP xác thực
CREATE TABLE IF NOT EXISTS auth_otps (
    id SERIAL PRIMARY KEY,
    target VARCHAR(255) NOT NULL,
    otp_code VARCHAR(10) NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    is_used BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
