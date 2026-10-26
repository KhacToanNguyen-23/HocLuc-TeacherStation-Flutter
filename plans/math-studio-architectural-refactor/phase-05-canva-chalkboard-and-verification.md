# Phase 05: Canva Chalkboard Sticker Polish & Comprehensive Verification Gate

**Status:** Not Started  
**Target Files:**
- `frontend/lib/features/studio_board/presentation/board_sticker_card.dart`
- `frontend/lib/features/studio_board/presentation/interactive_chalkboard.dart`
- `frontend/test/features/studio_board/board_sticker_test.dart`
- `plugins/math_studio.hlep`

---

## Technical Details

1. **Canva Interactive Object Capabilities:**
   - **8 Handles:**
     - 4 góc: Kéo scale tỷ lệ đồng dạng (giữ nguyên aspect ratio đồ thị).
     - 4 cạnh: Kéo dãn 1 chiều (width hoặc height).
   - **Nút xoay (Rotate Handle):**
     - Kéo xoay mượt mà, nam châm snap tự động tại các góc chuẩn: $0^\circ, 45^\circ, 90^\circ, 180^\circ, 270^\circ$.
   - **Thanh công cụ nổi (Floating Pill Bar):**
     - Đặt ở canvas overlay layer cao nhất, không bị che khuất hay nuốt sự kiện click.
     - Các nút: `Ghim` (bỏ chọn), `Phát quay` / `Sách GK`, `Sửa` (mở lại plugin với đúng thông số cũ), `Nhân bản`, `Xóa`.
   - **Double-Click Edit:**
     - Nhấp đúp vào sticker trên bảng chalkboard thì mở ngay Math Studio để sửa tiếp đồ thị đó.

2. **Automated Verification CI Gate (100% PASS):**
   - Đóng gói plugin: `node scripts/validate_plugins.mjs --fix`.
   - Kiểm tra kiến trúc: `node scripts/run_architecture_check.mjs` (12/12 Invariants PASS).
   - Flutter tests: `flutter test test/architecture_test.dart` và `flutter test test/features/studio_board/board_sticker_test.dart`.
   - Linter: `flutter analyze --no-fatal-infos` (0 errors, 0 warnings).

---

## Verification
- Xác nhận toàn bộ 12 bất biến kiến trúc và toàn bộ test suites đạt 100%.

