CREATE TABLE accounts (
 id VARCHAR(36) PRIMARY KEY, email VARCHAR(254) NOT NULL UNIQUE,
 name VARCHAR(200) NOT NULL, password_hash VARCHAR(100) NOT NULL,
 role VARCHAR(16) NOT NULL CHECK (role IN ('TEACHER','ADMIN')), created_at VARCHAR(40) NOT NULL
);
CREATE TABLE auth_sessions (
 token_hash VARCHAR(64) PRIMARY KEY, account_id VARCHAR(36) NOT NULL REFERENCES accounts(id),
 expires_at BIGINT NOT NULL
);
CREATE TABLE pdf_sources (
 id VARCHAR(36) PRIMARY KEY, logical_key VARCHAR(600) NOT NULL, checksum VARCHAR(64) NOT NULL UNIQUE,
 revision INTEGER NOT NULL CHECK (revision > 0), data TEXT NOT NULL,
 UNIQUE(logical_key, revision)
);
CREATE TABLE processing_jobs (
 id VARCHAR(36) PRIMARY KEY, source_id VARCHAR(36) NOT NULL REFERENCES pdf_sources(id), data TEXT NOT NULL
);
CREATE TABLE question_assets (
 id VARCHAR(36) PRIMARY KEY, source_id VARCHAR(36) NOT NULL REFERENCES pdf_sources(id), data TEXT NOT NULL
);
CREATE TABLE question_groups (
 id VARCHAR(36) PRIMARY KEY, source_id VARCHAR(36) NOT NULL REFERENCES pdf_sources(id), data TEXT NOT NULL
);
CREATE TABLE questions (
 id VARCHAR(36) PRIMARY KEY, source_id VARCHAR(36) NOT NULL REFERENCES pdf_sources(id),
 group_id VARCHAR(36) REFERENCES question_groups(id), status VARCHAR(24) NOT NULL,
 fingerprint VARCHAR(64) NOT NULL, data TEXT NOT NULL
);
CREATE INDEX questions_review_idx ON questions(status);
CREATE TABLE question_reviews (
 id VARCHAR(36) PRIMARY KEY, question_id VARCHAR(36) NOT NULL REFERENCES questions(id),
 reviewer_id VARCHAR(36) NOT NULL REFERENCES accounts(id), data TEXT NOT NULL
);
CREATE TABLE matrix_versions (id VARCHAR(100) PRIMARY KEY, data TEXT NOT NULL);
CREATE TABLE papers (
 id VARCHAR(36) PRIMARY KEY, teacher_id VARCHAR(36) NOT NULL REFERENCES accounts(id),
 matrix_id VARCHAR(100) NOT NULL REFERENCES matrix_versions(id), data TEXT NOT NULL
);
CREATE INDEX papers_owner_idx ON papers(teacher_id);
CREATE TABLE paper_items (
 paper_id VARCHAR(36) NOT NULL REFERENCES papers(id), position INTEGER NOT NULL CHECK(position > 0),
 question_id VARCHAR(36) NOT NULL REFERENCES questions(id), snapshot TEXT NOT NULL,
 PRIMARY KEY(paper_id, position), UNIQUE(paper_id, question_id)
);
CREATE TABLE export_records (
 id VARCHAR(36) PRIMARY KEY, paper_id VARCHAR(36) NOT NULL REFERENCES papers(id), data TEXT NOT NULL
);
CREATE TABLE classes (
 id VARCHAR(36) PRIMARY KEY, teacher_id VARCHAR(36) NOT NULL REFERENCES accounts(id), data TEXT NOT NULL
);
CREATE TABLE students (
 id VARCHAR(36) PRIMARY KEY, teacher_id VARCHAR(36) NOT NULL REFERENCES accounts(id),
 student_code VARCHAR(100) NOT NULL, data TEXT NOT NULL, UNIQUE(teacher_id, student_code)
);
CREATE TABLE class_memberships (
 class_id VARCHAR(36) NOT NULL REFERENCES classes(id), student_id VARCHAR(36) NOT NULL REFERENCES students(id),
 PRIMARY KEY(class_id,student_id)
);
CREATE TABLE exam_sessions (
 id VARCHAR(36) PRIMARY KEY, teacher_id VARCHAR(36) NOT NULL REFERENCES accounts(id),
 class_id VARCHAR(36) NOT NULL REFERENCES classes(id), paper_id VARCHAR(36) NOT NULL REFERENCES papers(id), data TEXT NOT NULL
);
CREATE TABLE student_results (
 id VARCHAR(36) PRIMARY KEY, teacher_id VARCHAR(36) NOT NULL REFERENCES accounts(id),
 session_id VARCHAR(36) NOT NULL REFERENCES exam_sessions(id), student_id VARCHAR(36) NOT NULL REFERENCES students(id),
 evidence_level VARCHAR(16) NOT NULL CHECK(evidence_level IN ('DETAILED','AGGREGATE')),
 data TEXT NOT NULL, UNIQUE(session_id, student_id)
);
CREATE TABLE answer_records (
 result_id VARCHAR(36) NOT NULL REFERENCES student_results(id), position INTEGER NOT NULL,
 question_id VARCHAR(36) NOT NULL REFERENCES questions(id), answer TEXT NOT NULL, correct BOOLEAN NOT NULL,
 PRIMARY KEY(result_id,position)
);
CREATE TABLE import_jobs (
 id VARCHAR(36) PRIMARY KEY, teacher_id VARCHAR(36) NOT NULL REFERENCES accounts(id),
 session_id VARCHAR(36) REFERENCES exam_sessions(id), data TEXT NOT NULL
);
