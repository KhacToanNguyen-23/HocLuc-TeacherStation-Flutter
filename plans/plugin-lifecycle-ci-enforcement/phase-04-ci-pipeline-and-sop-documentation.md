# Phase 04: CI Pipeline & SOP Documentation

**Parent Plan:** [plan.md](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/plans/plugin-lifecycle-ci-enforcement/plan.md)  
**Status:** Completed  
**Target Files:**
- `.github/workflows/ci-frontend.yml`
- `AGENTS.md`
- `.agents/rules/plugin_development_rules.md`
- `docs/architecture/plugin-development-guide.md`

---

## 1. Mục Tiêu & Yêu Cầu

Đồng bộ toàn bộ quy trình lên pipeline CI của GitHub và cập nhật tài liệu chuẩn (SOP) để cả lập trình viên con người và các AI Agent đều phải tuân thủ nghiêm ngặt.

### Tiêu chí nghiệm thu:
1. **GitHub Actions Early Exit Step:**
   - Trong file `.github/workflows/ci-frontend.yml`, bổ sung bước chạy `node scripts/validate_plugins.mjs` trước khi chạy `flutter pub get` hoặc `flutter test`.
   - Nếu phát hiện vi phạm plugin hoặc lệch `.hlep`, CI sẽ báo fail chỉ sau 5 giây thay vì phải đợi 2 phút.
2. **Cập nhật `AGENTS.md` & `.agents/rules/plugin_development_rules.md`:**
   - Bổ sung quy định bắt buộc chạy `node scripts/setup_hooks.mjs` khi bắt đầu làm việc.
   - Thêm quy chuẩn chi tiết cho 3 thao tác: THÊM mới, CHỈNH SỬA, và XÓA plugin.
   - Bổ sung mẫu Checklist PR bắt buộc (Pull Request Checklist).
3. **Cập nhật `docs/architecture/plugin-development-guide.md`:**
   - Hướng dẫn Developer cách kích hoạt pre-commit hook.
   - Hướng dẫn cách dùng cờ `--fix` của `validate_plugins.mjs`.
   - Hướng dẫn cấu hình Branch Protection trên GitHub để khóa nhánh `main` và `develop`.

---

## 2. Các Bước Triển Khai

1. Chỉnh sửa `.github/workflows/ci-frontend.yml` thêm step validation sớm.
2. Cập nhật `AGENTS.md` với các quy tắc mới về hook và kiểm tra đồng bộ.
3. Cập nhật `.agents/rules/plugin_development_rules.md`.
4. Cập nhật `docs/architecture/plugin-development-guide.md`.
5. Đánh giá toàn bộ pipeline bằng cách chạy thử `validate_plugins.mjs` và `architecture_test.dart`.

