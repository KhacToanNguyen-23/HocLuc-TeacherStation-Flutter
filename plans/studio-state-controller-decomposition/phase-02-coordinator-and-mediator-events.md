# Phase 2: Thiết lập StudioWorkspaceCoordinator & Event Mediator

## Mục tiêu
Tạo ra `StudioWorkspaceCoordinator` đóng vai trò nhạc trưởng (Mediator), nắm giữ instance của 4 Controller con, điều phối các luồng sự kiện chéo giữa các miền mà không cho phép các Controller con giữ tham chiếu trực tiếp đến nhau.

## Nhiệm vụ cụ thể
- [ ] Định nghĩa các Domain Events để giao tiếp lỏng lẻo (Loose Coupling):
  - `PluginSnipRegionEvent(target, rect)`: Khi plugin yêu cầu chụp vùng PDF/Canvas.
  - `PdfPageChangedEvent(pageIndex)`: Khi trang PDF chuyển đổi, cần đồng bộ Smart Pen index.
  - `SmartPenAnswerSelectedEvent(selection)`: Khi Smart Pen nhận diện được khoanh tròn đáp án.
  - `BoardDirtyStateChangedEvent(isDirty)`: Khi bảng vẽ có thay đổi cần lưu.
- [ ] Triển khai `StudioWorkspaceCoordinator extends ChangeNotifier`:
  - Sở hữu các trường: `title`, `subject`, `notes`, `question`, `endpoint`, `language`, `dirty`, `saving`, `isPlanningMode`.
  - Quản lý lifecycle tập trung:
    ```dart
    final CanvasDrawingController canvas;
    final PdfSmartPenController pdf;
    final AudioSyncController audio;
    final StudioPluginBridgeController plugins;
    ```
  - Lắng nghe sự kiện từ `plugins` để điều khiển `canvas` hoặc `pdf` (ví dụ: `insertPluginCard`, `highlightPdfPassageFromAnalysis`).
  - Quản lý Serialization/Deserialization (di chuyển từ `studio_state_serialization.dart`): `exportLessonJson()`, `restoreFromJson(map)`.
  - Phương thức `dispose()`: Gọi `dispose()` tuần tự trên cả 4 controllers con và dọn sạch các subscription.

## Tiêu chí chấp nhận
- Không có bất kỳ import chéo nào giữa `CanvasDrawingController`, `PdfSmartPenController`, `AudioSyncController`, `StudioPluginBridgeController`.
- Mọi tương tác liên miền đều đi qua Mediator callbacks/events của `StudioWorkspaceCoordinator`.
- Unit test mediator: `flutter test test/features/studio_board/controllers/coordinator_test.dart` pass 100%.
