# Phase 04 — Học liệu dùng được và chia sẻ

Status: Core code implemented; Classroom sandbox pending; optional DOCX/PPTX conversion remains disabled. Covers R06–09; R10 deferred by compatibility gate.

## Công việc

- Tài liệu đã tạo có audience label, preview, download và publish chọn lọc. Giữ PDF Java native độc lập speech/runtime/API; học sinh không có notes/đáp án.
- Giữ templates mapping/preview, class variants, approved questions, reuse, reflection/history/diff. Không duplicate store hoặc mất planning IDs.
- Classroom thao tác trong app, verified session/integration grants, external OAuth consent khi bắt buộc; không bắt login lại mỗi lần. Publish retry idempotent, lỗi có hành động phục hồi.
- AI authoring external configurable tùy chọn với consent; STT/dịch/TTS local model giữ nguyên định hướng. Availability rõ, kết quả draft không tự thay bài. Video giữ nhưng rollout sau core, gate riêng không là prerequisite.
- DOCX P2 optional: hỗ trợ paragraph text import/export cơ bản với corpus thử Word/LibreOffice, Unicode, paragraph/list; báo bảng/hình/layout unsupported, giữ file gốc. Nếu compatibility chưa đạt thì disable conversion, vẫn attachment. PPTX chỉ attach; preview conversion để sau, không hứa native editing.

## Gate

A19–24 tương ứng feature enabled. A22 cần tài khoản sandbox và receiver thật; thiếu credentials = BLOCKED, không PASS. DOCX optional chưa đạt không chặn core nếu UI không hứa chức năng chưa hỗ trợ.
