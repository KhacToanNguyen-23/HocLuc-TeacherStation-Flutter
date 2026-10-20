# Phase 02: Cross-Platform Git Pre-Commit Hook (`.githooks/pre-commit`)

**Parent Plan:** [plan.md](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/plans/plugin-lifecycle-ci-enforcement/plan.md)  
**Status:** Completed  
**Target Files:**
- `.githooks/pre-commit`
- `.gitattributes`
- `scripts/setup_hooks.mjs`

---

## 1. Mục Tiêu & Yêu Cầu

Thiết lập cơ chế Git Hook tự động chặn commit ngay tại máy cục bộ của Developer hoặc AI Agent trước khi mã nguồn được đẩy lên repository.

### Tiêu chí nghiệm thu:
1. **Zero-npm Native Hook:**
   - Sử dụng cơ chế bản địa `git config core.hooksPath .githooks`. Không cài thư viện cồng kềnh như Husky hay lint-staged.
   - Thư mục `.githooks/` được lưu trong Git version control để mọi người khi clone repo về đều có thể kích hoạt ngay.
2. **Triệt tiêu lỗi xuống dòng Windows (CRLF vs LF):**
   - Thêm quy tắc vào `.gitattributes`:
     ```gitattributes
     .githooks/* text eol=lf
     scripts/*.mjs text eol=lf
     ```
   - Đảm bảo hook script chạy mượt trên Git Bash, WSL, Linux, macOS mà không bị lỗi `/bin/sh^M`.
3. **Nội dung `.githooks/pre-commit`:**
   - Gọi `node scripts/validate_plugins.mjs`.
   - Nếu exit code khác 0 -> Chặn commit (`exit 1`) và in thông báo hướng dẫn.
4. **Script kích hoạt 1 chạm `scripts/setup_hooks.mjs`:**
   - Giúp dev chỉ cần chạy `node scripts/setup_hooks.mjs` là tự động cấu hình `git config core.hooksPath .githooks` và cấp quyền thực thi.

---

## 2. Các Bước Triển Khai

1. Cập nhật `.gitattributes` ở thư mục gốc.
2. Tạo thư mục `.githooks/` và file `.githooks/pre-commit`.
3. Cấp quyền execute bit trong Git index: `git update-index --chmod=+x .githooks/pre-commit`.
4. Tạo script thiết lập tiện lợi `scripts/setup_hooks.mjs`.
5. Kiểm thử commit thử nghiệm trên môi trường Windows.

