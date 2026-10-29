# Plan: Tái cấu trúc Toàn diện Math Studio & Áp dụng Công nghệ Excalidraw + Giải tích THPT

Mode: Hard
Risk: normal — multi-file refactor in frontend and plugin, fully testable with architecture_test and validate_plugins, no schema or remote auth changes.
Spec: plans/flexible-math-studio-refactor/spec.md
Brainstorm: plans/reports/261029-flexible-math-studio-refactor-brainstorm.md
Date: 2026-10-29

---

## Overview
Dọn dẹp triệt để toàn bộ mã nguồn thừa và tàn dư code smell tích tụ qua nhiều lần sửa đổi; trả lại Flutter Host thành Microkernel thuần khiết (0 dòng code toán học); tái cấu trúc plugin `math_studio` thành gói Web độc lập chuẩn Marketplace gồm 3 trang chuyên sâu:
1. **Trang 1: Đồ thị & Khảo sát hàm số**: Ô nhập gọn gàng hiện ngay $y'$, khảo sát đơn điệu, cực trị, tiệm cận, nguyên hàm, tương tác 2 chiều (kéo điểm $M$ trượt tiếp tuyến, kéo đường $y=m$ biện luận nghiệm).
2. **Trang 2: Bảng biến thiên (BBT)**: Bảng số liệu toàn màn hình chuẩn SGK dạng vector phấn bảng.
3. **Trang 3: Tích phân & Khối tròn xoay**: Mô phỏng bản chất tích phân bằng Tổng Riemann (thanh trượt số hình chữ nhật $n$) và Khối tròn xoay 3D render trực tiếp từ đồ thị với nét liền/nét đứt chuẩn SGK và xoay đa góc nhìn.
Toàn bộ đồ thị được dựng trên nền Excalidraw nét phấn tự nhiên, không đè lấn chữ, ghim lên bảng đen với 8 điểm neo Canva co giãn và xoay $360^\circ$ tự do.

---

## Phase Breakdown

### [x] Phase 1: Thanh lọc mã nguồn Flutter Host (Purge Host Bleed & Restore Clean Microkernel)
- **File**: `plans/flexible-math-studio-refactor/phase-01-purge-flutter-host-bleed.md`
- **Mục tiêu**: Xóa `native_plugin_host.dart`, `native_scene_canvas.dart`, `native_plugin_runtime.dart`, gỡ `flutter_js` khỏi `pubspec.yaml`, đưa `floating_plugin_window.dart` về `FlatHost` duy nhất.
- **Stories**: [P1] Purge Flutter Host Bleed.

### [x] Phase 2: Thanh lọc mã nguồn Plugin Math Studio & Thiết lập Excalidraw
- **File**: `plans/flexible-math-studio-refactor/phase-02-purge-plugin-smells-setup-excalidraw.md`
- **Mục tiêu**: Xóa thư mục `logic/` QuickJS, xóa các file CAS/Exporter trùng lặp, thanh lọc regex ép kiểu, thiết lập khung Excalidraw Canvas nét phấn tự nhiên trong `ui/`.
- **Stories**: [P1] Purge Plugin Code Smells, [P1] Dynamic Math Parser.

### [x] Phase 3: Triển khai 3 Trang Chuyên sâu & Tương tác 2 Chiều
- **File**: `plans/flexible-math-studio-refactor/phase-03-three-specialized-pages-and-interactions.md`
- **Mục tiêu**: Xây dựng Trang 1 (Đồ thị + Tiếp tuyến + $y=m$), Trang 2 (Bảng biến thiên), Trang 3 (Tích phân Riemann + Khối tròn xoay 3D chuẩn SGK).
- **Stories**: [P1] Compact Input & Calculus Core, [P1] Bidirectional Graph, [P1] Dedicated BBT, [P1] Riemann Sums & 3D Solids.

### [x] Phase 4: Ghim Bảng Đen Canva, Đóng gói Marketplace & Kiểm thử Toàn diện
- **File**: `plans/flexible-math-studio-refactor/phase-04-chalkboard-stamping-packaging-and-verification.md`
- **Mục tiêu**: Kết nối xuất ảnh nét cao sang bảng đen với 8 điểm neo Canva, đóng gói `math_studio.hlep`, chạy toàn bộ kiểm thử kiến trúc (12/12 invariants) và phân tích tĩnh (`flutter analyze`).
- **Stories**: [P1] Canva Transform Stamping, [P1] Offline Marketplace Packaging.

---

## Session Notes
<!-- Updated by cook automatically — do not edit manually -->

**Last active:** 2026-10-29 02:12
**Phase in progress:** Completed All Phases (Phase 1, Phase 2, Phase 3, Phase 4)
**Status:** All 4 phases implemented, verified, and passing 100%.

### Decisions made this session
- Purged 100% of math code from Flutter core (deleted native_plugin_host.dart, native_scene_canvas.dart, native_plugin_runtime.dart, spike test).
- Gỡ bỏ flutter_js khỏi pubspec.yaml; Flutter Host thuần khiết làm Microkernel trung lập.
- Cleaned up duplicate CAS engines and old regex hardcoding in plugins/math_studio/.
- Bundled 27KB rough.js (Excalidraw hand-drawn engine) into plugins/math_studio/ui/vendor/rough.js offline.
- Built 3 specialized tabs in Math Studio:
  - Tab 1: Đồ thị & Khảo sát (compact formula input + y', analysis cards, interactive dragging of point M for tangent and line y=m for root count).
  - Tab 2: Bảng biến thiên (BBT) vector SVG full-width with independent stamping.
  - Tab 3: Tích phân & Khối tròn xoay (Riemann rectangles slider n in [4, 50], 3D solids of revolution with textbook solid/dashed lines and 3D orbit rotation).
- Chalkboard Stamping protocol exports high-res transparent PNG/SVG with Canva 8-handle transformation border.
- Passed 100% Schema v2.1 validation and 12/12 architecture invariant tests.

### Next immediate action
Handoff to user for hands-on interactive classroom testing.


