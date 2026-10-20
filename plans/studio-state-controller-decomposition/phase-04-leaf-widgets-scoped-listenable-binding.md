# Phase 4: Tối ưu Scoped Listenable Rebuild cho các Leaf Widgets

## Mục tiêu
Tối ưu hóa phạm vi rebuild của Widget Tree trong `StudioScreen`, gắn trực tiếp các leaf widgets vào từng Controller chuyên biệt thay vì để toàn bộ màn hình lắng nghe `StudioState` chung, triệt tiêu hiện tượng lag giật khi vẽ nét liên tục.

## Nhiệm vụ cụ thể
- [x] Tách liên kết hiển thị trong `StrokeCanvas`:
  - Thực hiện: lớp laser của `StrokeCanvas` chỉ lắng nghe `laserOffsetNotifier` (trong `CanvasDrawingController`) + trail notifier; nét đang vẽ đã dùng `ValueNotifier` riêng. `StudioState.setLaserOffset` không còn `notifyListeners()` toàn cục.
  - `StrokeCanvas` vẫn được rebuild bởi `StageContainer` (đã tự `ListenableBuilder(studio)`) khi nét được commit — cần thiết để repaint nét.
- [~] Tách liên kết hiển thị trong `PdfStage`:
  - Hoãn: `PdfStage`/`PdfStageViewer` vẫn lắng nghe `StudioState` tổng hợp (đọc cả `tool`, `activeSubjectTool`, `smartSnapEnabled` từ nhiều controller). Chưa tách sang `PdfSmartPenController` riêng để tránh stale-state.
- [~] Tách liên kết hiển thị trong thanh Mic & Audio:
  - Hoãn: `AudioTranslationControls` đã lắng nghe `AudioTranslationService` riêng (không phụ thuộc rebuild của màn hình).
- [x] Tách liên kết hiển thị trong `StudioTopBar` & shell màn hình:
  - Thêm `ScopedListenableBuilder<T>` (selector-based). `StudioTopBar` chỉ rebuild khi `online/error/loading/saving/savedAt/dirty/title/view` đổi.
  - Root `StudioScreen` thay `AnimatedBuilder(studio)` bằng selector `(dirty, view)`; `StudioQuestionView` và `StudioSpeakerNotesBar` tự đăng ký lắng nghe.
- [x] Chạy kiểm thử UI widget tests: toàn bộ `test/features/studio_board/` (221 tests) + `architecture_test.dart` (12/12) pass; thêm `scoped_rebuild_test.dart`.

## Tiêu chí chấp nhận
- Không còn `notifyListeners()` toàn màn hình khi giáo viên di chuyển laser/hover; shell màn hình không rebuild khi vẽ/pdf/audio đổi.
- Widget tree được phân ranh giới theo selector của từng vùng (shell, top bar, stage).
