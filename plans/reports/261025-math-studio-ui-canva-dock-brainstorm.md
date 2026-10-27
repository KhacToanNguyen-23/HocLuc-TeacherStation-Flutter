# Brainstorm: Tái Thiết Kế UI Học Lực Math Studio (Canva-Style Object Manipulation & Fixed Dock)

**Date:** 2026-10-25

## Ideas Explored

1. **Floating Window / Desktop Modal Cũ:** Khung cửa sổ Windows trắng toát có title bar, nút đóng mở và các nút tab cồng kềnh $\rightarrow$ *Loại bỏ vì che khuất bảng giảng dạy và tạo cảm giác nặng nề.*
2. **NoteRenderer Direct Naming & Cloned UI:** Giữ nguyên tên "NoteRenderer" và bố cục sao chép $\rightarrow$ *Loại bỏ vì vi phạm thương hiệu và không trung thực về bản quyền mã nguồn.*
3. **Floating Math Dockbar Tự do (Hướng A):** Thu gọn plugin thành thanh công cụ mỏng dạng Dock nổi có định vị cố định (Fixed Dock), loại bỏ toàn bộ emoji và câu từ rườm rà, tập trung 100% vào học thuật (Academic Minimalist). $\rightarrow$ *Được chọn.*
4. **Canva-Style Object Manipulation trên Bảng Phấn:** Đối tượng sau khi ghim là vector đồ họa trong suốt 100%. Khi chạm vào mới hiện Bounding Box với 8 chốt co giãn (4 góc + 4 cạnh), 1 cuống xoay tự do và thanh hành động nổi. Khi click ra ngoài thì ẩn hoàn toàn viền bao. $\rightarrow$ *Được chọn.*
5. **Kéo nắn điểm cực trị 2 chiều (Inverse Curve Manipulation) trực tiếp trên mặt bảng:** Chạm vào điểm cực đại/cực tiểu của đồ thị trên bảng và kéo thả $\rightarrow$ đồ thị uốn lượn tại 60 FPS và công thức hàm số tự động cập nhật theo. $\rightarrow$ *Được chọn.*

## User's Direction

- **Giao diện Plugin:** Biến thành thanh công cụ Dock cố định, tinh gọn, thẩm mỹ sáng học thuật (Academic Light Palette: nền `#FFFFFF`/`#F8FAFC`, chữ mực xanh đen `#0F172A`, viền mỏng `#E2E8F0`).
- **Thanh nhập liệu:** Sửa triệt để lỗi nhập công thức toán học, gõ mượt mà và trực quan.
- **Xóa bỏ Emoji:** Thay toàn bộ icon cảm xúc bằng vector icon toán học thanh mảnh chuẩn mực.
- **Tên thương hiệu:** Đổi tên chính thức thành **Học Lực Math Studio** (hoặc Studio Toán Học), gỡ bỏ hoàn toàn tên "NoteRenderer".
- **Thao tác Đối tượng trên Bảng (Canva Style):**
  - Trạng thái bình thường: Hình vẽ hòa vào nền bảng, không viền, không header thừa thãi.
  - Trạng thái chọn: Bounding Box với Transform Controls 8 chốt (scale tỷ lệ ở góc, kéo giãn ở cạnh), chốt xoay đỉnh $\theta \in [0^\circ, 360^\circ]$, thanh tác vụ nổi `[ Sửa ]`, `[ Phát quay ]`, `[ Nhân bản ]`, `[ Xóa ]`.
  - Kéo nắn điểm cực trị 2 chiều hoạt động trực tiếp ngay trên bảng.

## Open Questions

- Độ nhạy ngưỡng kéo (Hit-box threshold) cho các điểm cực trị trên màn hình cảm ứng: Cần vùng bắt điểm tối thiểu $\ge 24\text{px}$ để ngón tay giáo viên kéo thả chính xác mà không bị nhầm với thao tác di chuyển cả hình.
- Phối hợp giữa cử chỉ cuộn bảng (Chalkboard Pan/Zoom) và cử chỉ Transform Control của đối tượng.

## Risks

1. **Xung đột cử chỉ Gesture Conflict:** Cử chỉ kéo góc/cạnh đối tượng có thể bị nhầm với cử chỉ vẽ phấn hoặc di chuyển bảng nếu hit-test không được phân tầng rõ ràng.
2. **Hiệu năng cập nhật 2 chiều khi kéo nắn cực trị:** Cần đảm bảo thuật toán nội suy đa thức (`computeFormulaFromDrag`) chạy trong $< 2\text{ms}$ để đạt độ mượt 60 FPS khi giáo viên kéo điểm trên mặt bảng.

