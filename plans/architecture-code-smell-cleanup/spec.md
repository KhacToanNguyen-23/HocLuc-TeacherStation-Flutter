# Feature Specification: Tái Cấu Trúc God Classes, Monolithic Screens & Chốt Chặn Kích Thước File Trên CI

**Slug**: `architecture-code-smell-cleanup`
**Created**: 2026-10-18
**Status**: Draft
**Brainstorm**: `plans/reports/261018-architecture-code-smell-cleanup-brainstorm.md`

---

## Overview

Sau khi hoàn tất kiến trúc Plugin Marketplace Schema v2.1, kết quả kiểm toán toàn bộ kho mã nguồn (`frontend/lib/` và `backend/api/`) cho thấy Backend đã đạt chuẩn модуl hóa tốt (mọi class `<360 dòng`), nhưng `frontend/lib/` vẫn tồn tại **3 God Files vượt ngưỡng 1,500–2,100 dòng**:
1. `frontend/lib/models/studio_state.dart` (**2,112 dòng**) — Gánh 7 miền trách nhiệm khác nhau trong một class `StudioState`.
2. `frontend/lib/screens/exams/exam_workspace_screen.dart` (**1,704 dòng**) — Chứa toàn bộ 8 tab quản lý đề thi và các hộp thoại trong một file duy nhất.
3. `frontend/lib/screens/classroom_dashboard_screen.dart` (**1,522 dòng**) — Trộn lẫn màn hình chính, quản lý lịch sử buổi học, tạo lớp và xuất PDF handout.

Đặc tả này định nghĩa quy trình phân rã (Modular Decomposition) các tệp trên thành các đơn vị nhỏ gọn theo miền trách nhiệm (Single Responsibility Principle) mà **không làm thay đổi bất kỳ Public API hay tọa độ hình học nào**, đồng thời bổ sung **Bất biến Kiến trúc #6 (Anti-God-Class Gate)** vào `frontend/test/architecture_test.dart` để ngăn chặn vĩnh viễn việc phát sinh file quá khổ trong tương lai.

---

## User Stories & Acceptance Criteria

### Story 1 — Phân rã God Object `studio_state.dart` (2,112 dòng) theo miền nghiệp vụ (Priority: P1)

Là một lập trình viên phát triển tính năng trên bảng giảng Studio, tôi muốn `studio_state.dart` được tách thành các tệp mô hình dữ liệu (`BoardStroke`, `BoardPage`, `ImportedDocument`...) và các nhóm hành vi riêng biệt để dễ đọc, dễ bảo trì và không bị xung đột Git khi làm việc nhóm.

**Why this priority**: `studio_state.dart` là tệp lớn nhất toàn dự án (`2,112 dòng`) và được import bởi hơn 40 tệp khác.

**Independent Test**: Chạy `flutter test test/studio_test.dart test/architecture_test.dart` và kiểm tra số dòng của `studio_state.dart` cùng các tệp tách ra đều dưới ngưỡng quy định, không một tệp nào bên ngoài phải sửa câu lệnh `import`.

**Acceptance Scenarios**:

1. **Given** `frontend/lib/models/studio_state.dart` hiện có `2,112 dòng`, **When** tách các model dữ liệu (`DrawingTool`, `ShapeType`, `BoardStroke`, `BoardShape`, `BoardPage`, `QuizQuestion`, `ImportedDocument`, `PdfDgnlPassage`) và các nhóm nghiệp vụ (Plugin/Snipping, PDF/Documents, Persistence) sang các tệp thành phần (`part` / `export`), **Then** tệp gốc `studio_state.dart` giảm xuống `<900 dòng` và mỗi tệp thành phần mới có kích thước `<550 dòng`.
2. **Given** hơn 40 tệp trong `frontend/lib/` và `frontend/test/` đang `import '../models/studio_state.dart'`, **When** biên dịch và chạy `flutter analyze --no-fatal-infos`, **Then** 100% tệp hiện có hoạt động bình thường mà không cần sửa đổi đường dẫn import.

---

### Story 2 — Phân rã Monolithic Screen `exam_workspace_screen.dart` (1,704 dòng) (Priority: P1)

Là một lập trình viên bảo trì phân hệ Đề thi & Ngân hàng câu hỏi, tôi muốn các tab chức năng và hộp thoại trong `exam_workspace_screen.dart` được tách thành các tệp thành phần rõ ràng để mỗi tệp chỉ đảm nhiệm một phần giao diện cụ thể.

**Why this priority**: `exam_workspace_screen.dart` dài `1,704 dòng`, ôm trọn 8 màn hình con của phân hệ khảo thí.

**Independent Test**: Chạy `flutter test test/exam_integration_test.dart test/visual_restyle_test.dart` — tất cả các bài test và tọa độ hình học của `ExamWorkspaceScreen` (`AppBar`, `ChoiceChip`, `ExamCard`, `ExamError`) phải giữ nguyên 100%.

**Acceptance Scenarios**:

1. **Given** `frontend/lib/screens/exams/exam_workspace_screen.dart` dài `1,704 dòng`, **When** tách các phần dựng giao diện tab (Tổng quan, Ngân hàng câu hỏi, Tạo đề, Thư viện đề, Lớp & học sinh, Kết quả, Phân tích, Nguồn PDF & Ma trận) thành các tệp thành phần trong `frontend/lib/screens/exams/`, **Then** `exam_workspace_screen.dart` và mọi tệp thành phần mới đều có số dòng `<900 dòng`.
2. **Given** bộ kiểm thử `visual_restyle_test.dart` kiểm tra tọa độ hình học trên 4 độ phân giải, **When** chạy `flutter test test/visual_restyle_test.dart`, **Then** tất cả các cảnh `exams`, `exam-bank-empty`, `exam-error`, và `exam-admin-1..8` đều pass 100%.

---

### Story 3 — Phân rã `classroom_dashboard_screen.dart` (1,522 dòng) & Chốt chặn CI chống God Class (Priority: P1)

Là trưởng nhóm kỹ thuật (Tech Lead), tôi muốn `classroom_dashboard_screen.dart` được thu gọn và có một bài kiểm tra tự động trong `architecture_test.dart` chặn mọi PR tạo ra file `.dart` vượt quá `1,200 dòng` hoặc file `.java` vượt quá `600 dòng`.

**Why this priority**: Đảm bảo sau khi dọn dẹp xong, không thành viên nào (hoặc AI Agent nào) có thể tái tạo lại file 1,500–2,000 dòng trong tương lai.

**Independent Test**: Chạy `flutter test test/architecture_test.dart test/visual_restyle_test.dart`.

**Acceptance Scenarios**:

1. **Given** `frontend/lib/screens/classroom_dashboard_screen.dart` dài `1,522 dòng`, **When** tách các hộp thoại và khu vực lịch sử buổi dạy/handout sang tệp thành phần, **Then** `classroom_dashboard_screen.dart` giảm xuống `<950 dòng`.
2. **Given** bộ kiểm thử `frontend/test/architecture_test.dart`, **When** chạy `flutter test test/architecture_test.dart`, **Then** **Bất biến 6** quét toàn bộ `frontend/lib/**/*.dart` (bắt buộc mọi file `\le 1,200 dòng`) và `backend/api/src/main/java/**/*.java` (bắt buộc mọi file `\le 600 dòng`) và báo pass 100%.

---

### Edge Cases

- **Tương thích với `visual_restyle_test.dart`:** Không đổi tên các Widget neo (`DashboardActionCard`, `ExamDashboardCard`, `DashboardEmptyCard`, `ExamCard`, `ChoiceChip`, `StudioTopBar`, `StageContainer`) và không chèn thêm lớp `Padding`/`Container` làm lệch tọa độ `[left, top, width, height]`.
- **Biến `_ private` giữa các file tách ra:** Sử dụng cơ chế `part` / `part of` của Dart cho các phần tách trực tiếp từ `StudioState`, `ExamWorkspaceScreen`, và `ClassroomDashboardScreen` để chia sẻ an toàn các biến trạng thái `_private` mà không cần mở rộng phạm vi truy cập (`public`) không cần thiết.

---

## Functional Requirements

- **FR-001**: Tách các class mô hình dữ liệu bảng vẽ (`BoardStroke`, `BoardShape`, `BoardPage`, `QuizQuestion`, `ImportedDocument`, `PdfDgnlPassage`) từ `studio_state.dart` sang `studio_board_models.dart`.
- **FR-002**: Tách các nhóm phương thức quản lý Plugin/Snipping và PDF/Tài liệu trong `StudioState` sang các file thành phần (`studio_state_plugins.dart`, `studio_state_documents.dart`).
- **FR-003**: Tách các phần dựng giao diện tab khảo thí và hộp thoại từ `exam_workspace_screen.dart` sang các tệp thành phần trong `frontend/lib/screens/exams/`.
- **FR-004**: Tách các hộp thoại và phần quản lý lịch sử/handout từ `classroom_dashboard_screen.dart` sang tệp thành phần.
- **FR-005**: Thêm **Bất biến 6 (Chống God Class / Monolithic File)** vào `frontend/test/architecture_test.dart` kiểm tra tự động trên CI: không có file `.dart` nào trong `frontend/lib/` vượt quá `1,200 dòng` và không có file `.java` nào trong `backend/api/src/main/java/` vượt quá `600 dòng`.

---

## Success Criteria

- **SC-001**: Số lượng file vượt quá `1,200 dòng` trong `frontend/lib/` giảm từ **3 file** (`2,112`, `1,704`, `1,522`) xuống **0 file**.
- **SC-002**: Kích thước `studio_state.dart` giảm ít nhất **55%** (từ `2,112 dòng` xuống `<900 dòng`).
- **SC-003**: `flutter analyze --no-fatal-infos` đạt **0 lỗi / 0 cảnh báo**.
- **SC-004**: Toàn bộ **6/6 bất biến kiến trúc** trong `flutter test test/architecture_test.dart` và toàn bộ **>274 bài kiểm thử** trong `flutter test` đạt **100% PASS**.

