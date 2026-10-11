-- =========================================================
-- Học Lực · Trạm Giảng Dạy (TeacherStation)
-- Script khởi tạo Cơ sở dữ liệu PostgreSQL cho Docker
-- =========================================================

CREATE TABLE IF NOT EXISTS users (
    id VARCHAR(64) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(20),
    role VARCHAR(50) DEFAULT 'TEACHER',
    avatar_url TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Seed tài khoản Demo Giáo viên: khactoan2233@gmail.com
INSERT INTO users (id, name, email, phone, role, avatar_url)
VALUES (
    'usr_demo_khactoan',
    'Thầy Khắc Toàn (Giáo viên Demo)',
    'khactoan2233@gmail.com',
    '+84988888888',
    'TEACHER',
    'https://lh3.googleusercontent.com/a/default-user'
)
ON CONFLICT (email) DO UPDATE 
SET 
    name = EXCLUDED.name,
    phone = EXCLUDED.phone,
    role = EXCLUDED.role;

-- Bảng lưu trữ lịch sử mã OTP xác thực
CREATE TABLE IF NOT EXISTS auth_otps (
    id SERIAL PRIMARY KEY,
    target VARCHAR(255) NOT NULL,
    otp_code VARCHAR(10) NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    is_used BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
