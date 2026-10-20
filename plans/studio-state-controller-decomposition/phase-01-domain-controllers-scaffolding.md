# Phase 1: Xây dựng 4 Domain Controllers độc lập

## Mục tiêu
Khởi tạo và đóng gói 4 Controller độc lập tại thư mục `frontend/lib/features/studio_board/services/controllers/`:
1. `CanvasDrawingController`: Quản lý danh sách các trang vẽ `pages`, nét bút `BoardStroke`, laser pointer, sticker, hình học.
2. `PdfSmartPenController`: Quản lý tài liệu PDF đang mở, cache trang, thuật toán nhận diện Smart Pen và các chú thích oval snapping.
3. `AudioSyncController`: Lắng nghe `TeacherMediaService` (Windows WASAPI) và điều khiển `AudioTranslationService`.
4. `StudioPluginBridgeController`: Đóng gói logic giao tiếp Webview/HostBridge (`handlePluginMessage`, `sendHostEvent`, danh sách plugin đang chạy, tọa độ cửa sổ floating).

## Nhiệm vụ cụ thể
- [ ] Tạo thư mục `frontend/lib/features/studio_board/services/controllers/`.
- [ ] Triển khai `CanvasDrawingController extends ChangeNotifier`:
  - Di chuyển các trường: `strokes`, `redoStrokes`, `activePage`, `tool`, `penColor`, `penSize`, `stickers`, `activeStickerIndex`.
  - Cung cấp các methods: `addPoint`, `endStroke`, `undo`, `redo`, `clearBoard`, `addSticker`, `switchPage`.
- [ ] Triển khai `PdfSmartPenController extends ChangeNotifier`:
  - Di chuyển logic PDF and Smart Pen: `pdfFile`, `pdfPages`, `pageSnapshots`, `smartPenClassifier`, `smartPenIndex`, `ovalAnnotations`.
  - Cung cấp các methods: `loadPdf`, `closePdf`, `detectSmartPenGesture`, `addOvalAnnotation`, `removeOvalAnnotation`.
- [ ] Triển khai `AudioSyncController extends ChangeNotifier`:
  - Khởi tạo và đồng bộ `AudioTranslationService`, `microphones`, `isMicActive`, `muted`.
  - Thiết lập phương thức `dispose()` hủy listener `TeacherMediaService` an toàn.
- [ ] Triển khai `StudioPluginBridgeController extends ChangeNotifier implements PluginHostBridge`:
  - Di chuyển các hàm xử lý plugin từ `studio_state_plugins.dart`: `handlePluginMessage`, `setPluginFloatingPosition`, `closeFloatingPlugin`.
- [ ] Viết unit test riêng cho từng controller trong `frontend/test/features/studio_board/controllers/`.

## Tiêu chí chấp nhận
- Cả 4 controller compile sạch, không import vòng lặp, mỗi file dưới 600 dòng code.
- Chạy unit test controller độc lập: `flutter test test/features/studio_board/controllers/` pass 100%.
