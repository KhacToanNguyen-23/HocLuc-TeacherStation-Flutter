# Plan: Math Studio Editorial UI & Zero-Latency UX Redesign

**Directory:** plans/math-studio-editorial-ui-ux/  
**Mode:** --hard  
**Risk:** normal — touches frontend plugin UI, CSS, and CAS logic, fully testable, no auth/data/infra risk  
**Spec Reference:** [spec.md](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/plans/math-studio-editorial-ui-ux/spec.md)  
**Brainstorm Report:** [261027-math-studio-editorial-ui-ux-brainstorm.md](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/plans/reports/261027-math-studio-editorial-ui-ux-brainstorm.md)

---

## Executive Summary
Kế hoạch tái thiết kế toàn diện giao diện và trải nghiệm người dùng của Học Lực Math Studio thành **Editorial Inspector 32% : 68% Live Canvas**. Dự án giải quyết triệt để 3 vấn đề cốt lõi:
1. **Loại bỏ tình trạng "Hộp lồng trong hộp" (Box-in-a-Box)**: Thay thế bằng các phân khu ngữ nghĩa với đường viền tóc thanh mảnh và hợp nhất ô nhập hàm thành một khối Hero duy nhất (loại bỏ ô xem trước xám trùng lặp).
2. **Bổ sung đầy đủ 4 trụ cột sư phạm SGK GDPT 2018**: Tính toán và hiển thị chính xác Khoảng đơn điệu ($\nearrow, \searrow$), Tâm đối xứng / Điểm uốn ($I$), Tiệm cận, và Cực trị; triệt tiêu 100% khoảng trắng chết ở cột trái.
3. **Tương tác hai chiều & Độ trễ cực thấp (< 16ms)**: Liên kết click highlight hai chiều giữa Inspector và đồ thị JSXGraph (Ripple Pulse effect), duy trì kiến trúc cập nhật đồ thị tại chỗ (In-Place Update) và biên dịch nhanh AST Evaluator.

---

## Phases Overview

| Phase | Title | Scope & Files | P1/P2 Stories Covered | Status |
| :--- | :--- | :--- | :--- | :--- |
| **01** | CAS Engine Extension: Monotonicity & Symmetry | `plugins/math_studio/ui/core/math_cas.js` | [P1] Complete SGK 2018 Analysis | [x] Completed |
| **02** | Hero Formula Block & Editorial Inspector (32:68) | `plugins/math_studio/ui/index.html`, `plugins/math_studio/ui/style.css` | [P1] Unified Input, [P1] Zero Dead Space | [x] Completed |
| **03** | Bidirectional Linking, Zero-Lag Wiring & CI Verification | `plugins/math_studio/ui/app.js`, `plugins/math_studio/ui/board/graph_board.js`, tests | [P1] Zero-Latency, [P2] Interactive Linking | [x] Completed |

---

## Session Notes
<!-- Updated by cook automatically — do not edit manually -->

**Last active:** 2026-10-27 15:18  
**Phase in progress:** Phase 03 Complete  
**Status:** All 3 phases implemented, validated, and passing 100% CI gates.

### Decisions made this session
- Unified Hero Formula Display with large STIX Two Math typography, integrating clear button and eliminating redundant gray preview boxes.
- Implemented 4 SGK GDPT 2018 pillars: Monotonicity intervals (↗, ↘), Extrema (CĐ, CT), Symmetry (Inflection U, Center I, Axis Δ), and Asymptotes.
- 32% : 68% golden split eliminating box-in-a-box syndrome and dead space.
- Bidirectional interactive linking: clicking property rows triggers smooth-pan and ripple pulse animation on canvas dots; clicking canvas dots auto-scrolls to and selects property rows.
- Passed 12/12 Flutter architecture invariants and 0 flutter analyze errors.

### Next immediate action
Handoff to user for interactive acceptance.

---

## Risk Analysis

- **Risk 1: Hiệu năng tính toán đạo hàm cấp 2 và nghiệm phân hoạch**:
  *Khắc phục*: Tận dụng `compileFastEvaluator` sẵn có trong `micro_cas.js` để tính toán sai phân cấp 2 siêu tốc ($> 20.000.000$ evals/giây), quét phân hoạch giới hạn trong khoảng $[x_{min}, x_{max}]$ đã lọc của viewport, giữ tổng thời gian tính toán $< 3\text{ms}$.
- **Risk 2: Xung đột ID hoặc gãy kết nối với Flutter Host Webview**:
  *Khắc phục*: Bảo tồn nguyên vẹn 100% danh mục 16 ID/Class cốt lõi đã được khảo sát (`#mathInput`, `#btnClearFormula`, `#btnToggleChips`, `#cardFormula`, `#extremaEditorContainer`, v.v.), chỉ thay đổi kiến trúc bao bọc và phong cách hiển thị.
- **Risk 3: Lỗi cú pháp hoặc mất đồng bộ gói .hlep**:
  *Khắc phục*: Kiểm tra cú pháp ES Module bằng Node.js trước khi đóng gói, chạy validator `validate_plugins.mjs`, và hoàn thành đầy đủ cổng `architecture_test.dart` (12/12) cùng `flutter analyze`.

