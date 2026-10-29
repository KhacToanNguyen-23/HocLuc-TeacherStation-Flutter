# Brainstorm: Stamp Graph to Chalkboard (Ghim đồ thị lên bảng đen)

**Date:** 2026-10-27

## Ideas Explored
1. **RepaintBoundary Snapshot (Flutter RenderObject -> PNG Base64)**: Bọc `NativeSceneCanvas` bằng `RepaintBoundary`. Khi giáo viên bấm "Ghim vào bảng", host chụp trực tiếp buffer hiển thị hiện tại ở độ phân giải cao (`pixelRatio: 2.0`) và gửi vào `imageBase64` của `BoardSticker`. Lấy đúng 100% từng pixel, góc quay, pan/zoom, không cần tính toán lại.
2. **Re-build Vector SVG Generator**: Viết thêm module xuất chuỗi SVG từ JS hoặc Flutter cho đồ thị và hình 3D. Bị loại vì vi phạm nguyên tắc "không tự build lại", tốn công sức và dễ lệch giao diện so với canvas đang tương tác.
3. **Offscreen PictureRecorder Simulation**: Gọi lại `CustomPainter` trên canvas ảo. Bị loại vì phức tạp hơn việc chụp trực tiếp `RepaintBoundary` đang có sẵn trên màn hình.

## User's Direction
- **Chỉ thị của người dùng**: *"bảng thông số render ra đồ thị như nào thì lấy cái đồ thị đó, không tự build lại"*.
- **Quyết định**: Chọn **Hướng 1 (RepaintBoundary Snapshot)**. Lấy trực tiếp ảnh chụp đồ thị đang hiển thị trên canvas ghim lên bảng đen; đồng thời giữ nguyên vector SVG cho tab BBT (Bảng biến thiên) vì engine đã có sẵn SVG chất lượng cao.

## Open Questions
1. Có cần ẩn các nút công cụ trôi (floating toolbar zoom in/out, reset viewport) trên canvas khi chụp không?
   - *Giải pháp*: `RepaintBoundary` chỉ bọc phần `CustomPaint` vẽ đồ thị/trục tọa độ, nằm dưới lớp floating buttons, do đó ảnh chụp sẽ sạch sẽ, chỉ có đồ thị toán học.

## Risks
1. **RepaintBoundary chưa sẵn sàng (null context/renderObject)**: Nếu người dùng bấm ghim ngay lập tức khi vừa mở plugin, `currentContext?.findRenderObject()` có thể chưa kết thúc layout pass.
   - *Khắc phục*: Thêm guard check và fallback nhẹ nếu chưa sẵn sàng.
2. **Kích thước payload Base64**: Ảnh chụp độ phân giải 2x có thể nặng nếu không nén hợp lý.
   - *Khắc phục*: Đồ thị trên nền phẳng nén PNG rất tốt (chỉ khoảng 50–120 KB), hoàn toàn tối ưu cho bộ nhớ và bus tin nhắn nội bộ của Flutter.

