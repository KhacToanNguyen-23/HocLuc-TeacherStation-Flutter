# Phase 04: Architecture Invariants & CI Enforcement

**Parent Plan:** [plan.md](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/plans/frontend-clean-architecture-and-plugin-cleanup/plan.md)  
**Status:** Completed  
**Target Files:**
- `frontend/test/architecture/architecture_test.dart` (hoặc `frontend/test/architecture_test.dart`)
- `AGENTS.md`
- `ARCHITECTURE.md`
- `.github/workflows/ci-frontend.yml`

---

## 1. Mục Tiêu & Yêu Cầu

Thiết lập hệ thống kiểm tra tự động để vĩnh viễn không bao giờ tái diễn tình trạng code manh múng và file trôi nổi:

1. **Bổ sung Bất biến 8 vào `architecture_test.dart`:**
   - Cấm file trôi nổi trực tiếp trong `lib/widgets/` và `lib/services/`. Mọi file UI/Service mới bắt buộc phải nằm trong các module con thuộc `lib/features/<module>/` hoặc `lib/core/`.
2. **Bổ sung Bất biến 9 vào `architecture_test.dart`:**
   - Cấm file test nằm phẳng ở thư mục gốc `test/`. Bắt buộc test mới phải đặt trong `test/features/`, `test/unit/`, hoặc `test/widgets/`.
3. **Bổ sung Bất biến 10 vào `architecture_test.dart`:**
   - Quét `frontend/pubspec.yaml`, cấm khai báo các package path trỏ tới thư mục không tồn tại.
4. **Cập nhật tài liệu quy chuẩn:**
   - Tạo file `ARCHITECTURE.md` mô tả ranh giới 4 feature modules và tầng `core/`.
   - Cập nhật `AGENTS.md` bổ sung các quy tắc bắt buộc về cấu trúc thư mục mới.
   - Cập nhật đường dẫn file test architecture trong `.github/workflows/ci-frontend.yml` nếu file test được di chuyển.

---

## 2. Tiêu Chí Nghiệm Thu

- Toàn bộ bài test kiến trúc mới chạy và đạt **PASS 100%**.
- CI trên GitHub Actions kích hoạt và xanh hoàn toàn.
- Tài liệu quy chuẩn đầy đủ, rõ ràng cho mọi dev và agent.

