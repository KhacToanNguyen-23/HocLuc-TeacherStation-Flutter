# Kế Hoạch Triển Khai: Tái Cấu Trúc God Classes, Monolithic Screens & Chốt Chặn Kích Thước File Trên CI

- **Slug:** `architecture-code-smell-cleanup`
- **Spec:** [`plans/architecture-code-smell-cleanup/spec.md`](spec.md)
- **Brainstorm:** [`plans/reports/261018-architecture-code-smell-cleanup-brainstorm.md`](../reports/261018-architecture-code-smell-cleanup-brainstorm.md)
- **Mode:** `--fast`
- **Risk:** `normal — multi-file structural decomposition via Dart part/part-of with zero behavior or geometry changes`
- **Created:** 2026-10-18

---

## Tổng Quan Kiến Trúc & Chiến Lược Không Gây Lỗi Hồi Quy (Zero-Breaking Strategy)

Để giảm kích thước 3 tệp lớn nhất trong `frontend/lib/` xuống dưới ngưỡng `950 dòng/file` (và đảm bảo toàn bộ kho mã nguồn không có bất kỳ file `.dart` nào vượt quá `1,200 dòng`) mà **không làm thay đổi bất kỳ câu lệnh `import` nào của >40 tệp hiện có và không làm lệch 1 pixel nào trong `visual_restyle_test.dart`**, kế hoạch sử dụng cơ chế **`part` / `part of` kết hợp `extension` nội bộ cùng thư viện (same-library extension)** của Dart:

1. **Chia sẻ phạm vi thư viện (`library` scope):** Các tệp `part of 'studio_state.dart';`, `part of 'exam_workspace_screen.dart';`, và `part of 'classroom_dashboard_screen.dart';` nằm trong cùng một đơn vị biên dịch với tệp chính, do đó truy cập trực tiếp được các biến trạng thái `_private` và `setState` / `notifyListeners()` mà không cần phơi bày biến nội bộ ra `public`.
2. **Bảo toàn 100% cây Widget & Tọa độ Hình học:** Không bọc thêm bất kỳ Widget trung gian nào quanh `AppBar`, `ChoiceChip`, `ExamCard`, `DashboardActionCard`, `ExamDashboardCard`, `DashboardEmptyCard`, `StudioTopBar`, hay `StageContainer`.

---

## Danh Sách Các Giai Đoạn (Phases)

| Phase | Tên giai đoạn | Tệp kế hoạch | User Stories | Trạng thái |
| :---: | :--- | :--- | :---: | :---: |
| **01** | Phân rã `studio_state.dart` (`2,112 dòng` $\rightarrow$ 4 tệp `<850 dòng`) | [`phase-01-decompose-studio-state.md`](phase-01-decompose-studio-state.md) | Story 1 (P1) | Completed |
| **02** | Phân rã `exam_workspace_screen.dart` (`1,704 dòng` $\rightarrow$ 3 tệp `<750 dòng`) | [`phase-02-decompose-exam-workspace-screen.md`](phase-02-decompose-exam-workspace-screen.md) | Story 2 (P1) | Completed |
| **03** | Phân rã `classroom_dashboard_screen.dart` (`1,522 dòng` $\rightarrow$ 2 tệp `<880 dòng`) & Thêm Bất biến #6 vào `architecture_test.dart` | [`phase-03-decompose-dashboard-and-ci-gate.md`](phase-03-decompose-dashboard-and-ci-gate.md) | Story 3 (P1) | Completed |

