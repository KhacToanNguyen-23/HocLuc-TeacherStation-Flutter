# Phase 2: Chụp ảnh Snapshot và Đóng gói Sticker Dispatch

## Mục tiêu
Khi người dùng bấm "Ghim vào bảng", trích xuất buffer hình ảnh từ `RenderRepaintBoundary` thành PNG Base64 đối với các tab Đồ thị, Tích phân, Hình 3D (hoặc giữ chuỗi SVG đối với BBT) và gửi đầy đủ payload sang `HostBridge`.

## File tác động
- `frontend/lib/features/plugin_engine/presentation/native_plugin_host.dart`

## Các bước triển khai
1. Trong `_NativePluginHostState`, khai báo:
   ```dart
   final GlobalKey _canvasRepaintBoundaryKey = GlobalKey();
   ```
2. Truyền `repaintBoundaryKey: _canvasRepaintBoundaryKey` vào `NativeSceneCanvas`.
3. Chuyển hàm `_stampToBoard()` thành hàm `Future<void> _stampToBoard() async`:
   - Nếu `activeTab == 'bbt'`:
     - Lấy `svgContent = scene?['svg'] as String?`.
   - Nếu `activeTab != 'bbt'` (graph, integral, geom3d):
     - Truy cập `final boundary = _canvasRepaintBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;`.
     - Nếu `boundary != null`:
       ```dart
       final image = await boundary.toImage(pixelRatio: 2.0);
       final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
       if (byteData != null) {
         final pngBytes = byteData.buffer.asUint8List();
         imageBase64 = 'data:image/png;base64,${base64Encode(pngBytes)}';
       }
       ```
4. Đóng gói vào payload tin nhắn `board:insert_annotation`:
   ```dart
   'data': {
     'pluginId': widget.plugin.manifest.id,
     'stickerId': editing?.id,
     'title': title,
     'rawText': rawText,
     'svgContent': svgContent,
     'imageBase64': imageBase64,
     'metadata': metadata,
     'aspectRatio': activeTab == 'bbt' ? 1.6 : 1.33,
   }
   ```
5. Đảm bảo nút "Ghim vào bảng" trong header gọi `_stampToBoard()` an toàn, vô hiệu hoá tạm thời trong lúc snapshot đang chạy để tránh bấm đúp (debounce/loading indicator nhẹ nếu cần).

## Tiêu chí hoàn thành (Verification)
- Thẻ sticker trên bảng đen nhận được `imageBase64` hợp lệ, hiển thị hình ảnh đồ thị rõ ràng và tương phản tốt trên nền bảng đen.

