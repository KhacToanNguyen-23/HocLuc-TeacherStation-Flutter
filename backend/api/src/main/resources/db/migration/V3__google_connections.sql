CREATE TABLE exam_platform.google_connections (
    subject VARCHAR(255) PRIMARY KEY,
    email VARCHAR(320) NOT NULL,
    credentials TEXT NOT NULL
);
CREATE TABLE exam_platform.google_courses (
    id VARCHAR(64) PRIMARY KEY,
    subject VARCHAR(255) NOT NULL,
    data TEXT NOT NULL
);
