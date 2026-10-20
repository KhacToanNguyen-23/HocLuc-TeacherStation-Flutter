# Phase 03: Mở rộng Chốt chặn Kiến trúc (Invariants 11 & 12)

## Mục tiêu
Tự động hóa phòng thủ kiến trúc vĩnh viễn: không bao giờ cho phép bất kỳ ai tạo lại `lib/screens/`, `lib/models/`, `lib/theme/`, `lib/utils/` tại root.

## Các công việc cụ thể
1. **Bổ sung Invariant 11 vào `frontend/test/architecture_test.dart`:**
   - Cấm sự tồn tại của `lib/screens/` và `lib/models/`.
   - Nếu phát hiện bất kỳ file nào nằm trong `lib/screens/` hoặc `lib/models/`, test sẽ FAIL với thông báo hướng dẫn đưa vào `lib/features/<module>/presentation/screens/` hoặc `lib/features/<module>/domain/models/`.
2. **Bổ sung Invariant 12 vào `frontend/test/architecture_test.dart`:**
   - Cấm sự tồn tại của `lib/theme/`, `lib/utils/`, `lib/constants/` tại root.
   - Bắt buộc mọi tiện ích dùng chung phải nằm trong `lib/core/`.
3. **Cập nhật tài liệu quy chuẩn:**
   - Cập nhật [ARCHITECTURE.md](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/ARCHITECTURE.md) với sơ đồ Clean Architecture Feature-First 100% hoàn chỉnh.
   - Cập nhật [AGENTS.md](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/AGENTS.md) ghi nhận Invariants 11 và 12 vào Mandatory PR Checklist.

## Tiêu chí hoàn thành (Verification)
- `flutter test test/architecture_test.dart` (12/12 Invariants PASS 100%).

