# Phase 3: Chuyển đổi StudioState thành Facade & Xóa sổ 6 file `part of`

## Mục tiêu
Biến `StudioState` thành một Facade mỏng (Thin Wrapper) ủy quyền xuống `StudioWorkspaceCoordinator` và các domain controllers, cho phép xóa sổ vĩnh viễn 6 file `part of` đối phó CI mà không làm gãy bất kỳ một test case nào đang có trong dự án.

## Nhiệm vụ cụ thể
- [x] Chỉnh sửa `studio_state.dart`:
  - Loại bỏ hoàn toàn các dòng `part '...';`:
    - `part 'studio_state_plugins.dart';`
    - `part 'studio_state_annotations.dart';`
    - `part 'studio_state_smart_pen.dart';`
    - `part 'studio_state_pdf.dart';`
    - `part 'studio_state_serialization.dart';`
  - Giữ lại `StudioState extends ChangeNotifier implements PluginHostBridge`:
    - Sở hữu một instance `coordinator = StudioWorkspaceCoordinator(...)`.
    - Lắng nghe `coordinator.addListener(notifyListeners)` để bảo toàn tính năng reactive cũ cho các widget chưa kịp di chuyển.
    - Chuyển tiếp (forward/delegate) các getters/methods công khai cũ xuống controller tương ứng:
      ```dart
      List<BoardStroke> get strokes => coordinator.canvas.strokes;
      void addStroke(BoardStroke s) => coordinator.canvas.addStroke(s);
      bool get isMicActive => coordinator.audio.isMicActive;
      void handlePluginMessage(...) => coordinator.plugins.handlePluginMessage(...);
      ```
- [x] Xóa bỏ 5 file `part of` trên đĩa:
  - `frontend/lib/features/studio_board/domain/models/studio_state_annotations.dart`
  - `frontend/lib/features/studio_board/domain/models/studio_state_pdf.dart`
  - `frontend/lib/features/studio_board/domain/models/studio_state_plugins.dart`
  - `frontend/lib/features/studio_board/domain/models/studio_state_serialization.dart`
  - `frontend/lib/features/studio_board/domain/models/studio_state_smart_pen.dart`
- [x] Chạy kiểm thử toàn bộ test suite hiện có của `studio_board`:
  - `flutter test test/features/studio_board/studio_test.dart`
  - `flutter test test/features/studio_board/smart_pen_annotation_test.dart`
  - `flutter test test/features/studio_board/smart_pen_gesture_test.dart`
  - `flutter test test/features/studio_board/smart_pen_index_test.dart`
  - `flutter test test/features/studio_board/in_board_svo_e2e_test.dart`

## Tiêu chí chấp nhận
- 5 file `studio_state_*.dart` bị xóa hoàn toàn khỏi git.
- File `studio_state.dart` giảm dung lượng xuống còn một facade mỏng $\le 400$ dòng code sạch.
- 100% test suite hiện có chạy pass xanh mà không phải sửa nội dung các file test.
