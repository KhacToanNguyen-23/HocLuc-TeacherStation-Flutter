# Brainstorm: Canva-Style Object Manipulation & Đồ Thị Đồng Bộ 2 Chiều

**Date:** 2026-10-26

## Ideas Explored
1. **Trụ cột 1: Object Manipulation (Transform Controls chuẩn Canva)**
   - Khắc phục lỗi thiếu `height` trong `Positioned` của `interactive_chalkboard.dart` khiến chiều cao không thể co dãn.
   - 4 góc: Phóng to / Thu nhỏ (Scale / Proportional Resize) có khóa tỷ lệ (Aspect Ratio Lock).
   - 4 cạnh: Kéo dãn chiều rộng (Stretch Width) và chiều cao (Stretch Height) độc lập.
   - Xoay (Rotate): Chốt xoay trên đỉnh với giải thuật góc cực $\theta = \text{atan2}(dy, dx) - \theta_0$ mượt mà.
   - Di chuyển (Move / Drag): Bắt sự kiện kéo trên khung Bounding Box.
2. **Trụ cột 2: Đồng bộ dữ liệu 2 chiều khi chỉnh sửa (In-Place Edit Sync)**
   - Lưu trữ `metadata` (công thức `formula`, mút cận `a`, `b`) trong `BoardSticker`.
   - Khi bấm `✏️ Sửa`: Mở cửa sổ Math Studio nổi bên cạnh, nạp đúng dữ liệu của sticker được chọn ($y = x^2 - 3, a = -1, b = 5$).
   - Khi bấm "Xong": Gửi RPC cập nhật đè trực tiếp lên sticker hiện tại (`updateSticker`), không tạo sticker trùng lặp.

## User's Direction
- **Mục 1 (Transform Controls):** Đồng ý triển khai toàn diện bộ thao tác đối tượng chuẩn Canva.
- **Mục 2 (Cơ chế mở panel lúc sửa):** Chọn **Lựa chọn B (Cửa sổ nổi Floating Window)**: mở cửa sổ Math Studio nạp đúng thông số của sticker hiện tại, cập nhật đè in-place khi xong.

## Technical Root Causes Identified
1. **Mất thuộc tính height:** `Positioned` trong `interactive_chalkboard.dart` chỉ có `width`, thiếu hoàn toàn `height`, làm tê liệt thao tác kéo dãn chiều cao.
2. **Không có metadata sticker:** `BoardSticker` chỉ lưu chuỗi SVG tĩnh và rawText, không lưu đối tượng toán học gốc (`formula`, `bounds`).
3. **HostBridge tạo mới thay vì update:** `HostBridge._handleInsertAnnotation` luôn gán `id = sticker-${timestamp}` và gọi `addSticker`, dẫn đến không thể cập nhật đè.

## Risks & Mitigations
- Ràng buộc kích thước tối thiểu: Đặt kích thước tối thiểu $120 \times 80\text{px}$ để sticker không bị co về $0$.
- Phân biệt giữa tạo mới và chỉnh sửa: Thêm trường `editingStickerId` vào payload RPC để HostBridge nhận biết.

