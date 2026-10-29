# Phase 1: RepaintBoundary trên Canvas CustomPaint

## Mục tiêu
Cho phép lớp cha (`NativePluginHost`) có thể truy cập `RenderRepaintBoundary` của phần vẽ đồ thị/trục tọa độ toán học trong `NativeSceneCanvas` để chụp ảnh raster sắc nét mà không bị dính các nút công cụ trôi (floating toolbar zoom/reset).

## File tác động
- `frontend/lib/features/plugin_engine/presentation/native_scene_canvas.dart`

## Các bước triển khai
1. Thêm tham số `final GlobalKey? repaintBoundaryKey;` vào `NativeSceneCanvas`.
2. Trong hàm `build` của `_NativeSceneCanvasState`:
   - Bọc widget `AnimatedBuilder` (chứa `CustomPaint` vẽ đồ thị / lưới tọa độ / điểm mút / hình 3D) bằng `RepaintBoundary`:
     ```dart
     Positioned.fill(
       child: RepaintBoundary(
         key: widget.repaintBoundaryKey,
         child: AnimatedBuilder(
           animation: _pulseController,
           builder: (context, _) {
             return CustomPaint(
               painter: _SceneCustomPainter(
                 scene: widget.scene,
                 panOffset: _panOffset,
                 scale: _zoomScale,
                 pulseValue: _pulseController.value,
                 isWireframe: type == 'wireframe_3d',
               ),
             );
           },
         ),
       ),
     ),
     ```
   - Giữ nguyên các widget điều khiển zoom in/out và reset viewport ở lớp Stack bên trên (ngoài RepaintBoundary) để ảnh chụp chỉ chứa đồ thị sạch sẽ.

## Tiêu chí hoàn thành (Verification)
- `NativeSceneCanvas` nhận `repaintBoundaryKey` hợp lệ và không gây lỗi render hay overflow.

