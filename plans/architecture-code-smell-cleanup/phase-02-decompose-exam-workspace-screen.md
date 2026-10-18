# Phase 02: Phân Rã Monolithic Screen `exam_workspace_screen.dart` (1,704 dòng)

- **Covers:** Story 2 (P1) — Phân rã Monolithic Screen `exam_workspace_screen.dart`
- **Target Files:**
  - `frontend/lib/screens/exams/exam_workspace_screen.dart` (Giảm từ `1,704 dòng` xuống `<750 dòng`: Giữ khung màn hình chính, tab Tổng quan, Ngân hàng câu hỏi, Tạo đề, Thư viện đề)
  - `frontend/lib/screens/exams/exam_workspace_classes_and_results.dart` (Mới — ~440 dòng: Tab Lớp & Học sinh `classes()`, Tab Kết quả kiểm tra `results()`, `sessionResults()`, `importFile()`)
  - `frontend/lib/screens/exams/exam_workspace_analytics_and_sources.dart` (Mới — ~450 dòng: Tab Phân tích năng lực `analytics()`, Tab Nguồn PDF & Duyệt `sources()`, `uploadSources()`, `reviewQuestion()`, Tab Ma trận `matrices()`)

## Các Bước Thực Hiện
1. Tạo `frontend/lib/screens/exams/exam_workspace_classes_and_results.dart` với `part of 'exam_workspace_screen.dart';` chứa `extension _ExamWorkspaceClassesAndResultsExt on _ExamWorkspaceScreenState`.
2. Tạo `frontend/lib/screens/exams/exam_workspace_analytics_and_sources.dart` với `part of 'exam_workspace_screen.dart';` chứa `extension _ExamWorkspaceAnalyticsAndSourcesExt on _ExamWorkspaceScreenState`.
3. Khai báo `part` trong `exam_workspace_screen.dart` và xóa phần mã đã chuyển sang 2 tệp thành phần.

## Tiêu Chí Nghiệm Thu (Verification)
- `flutter test test/exam_integration_test.dart test/visual_restyle_test.dart` pass 100%.

