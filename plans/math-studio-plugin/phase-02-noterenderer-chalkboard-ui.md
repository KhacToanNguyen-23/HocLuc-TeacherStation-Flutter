# Phase 2: NoteRenderer Bounding Box & Floating Context Bar trên Bảng Phấn

**Goal:** Tái hiện 100% linh hồn UI/UX NoteRenderer trên mặt bảng phấn Studio Board của Flutter, biến đồ thị thành đối tượng bản xứ tương tác tự nhiên.

---

## Detailed Tasks

1. **Khung Bounding Box Nét đứt (NoteRenderer Selection Box):**
   - Nâng cấp `BoardStickerCard` trong `frontend/lib/features/studio_board/presentation/board_sticker_card.dart`.
   - Khi sticker được chọn (Active/Focused):
     - Bao bọc quanh hình bằng viền nét đứt màu nâu cam ấm (`#d97706` / `#f59e0b`) hoặc vàng phấn (`#fde047`).
     - 4 chốt góc vuông 10x10 px ở 4 góc cho phép giáo viên kéo chuột/chạm tay để co giãn tỷ lệ (Resize).
     - 1 chốt tròn có cuống vươn lên ở giữa mép trên (Rotation Stem) cho phép xoay góc hình.
   - Nền đối tượng 100% trong suốt, hòa trọn vẹn vào màu xanh và ô ly caro của mặt bảng phấn.

2. **Thanh công cụ ngữ cảnh nổi (Floating Context Bar):**
   - Đặt lơ lửng ngay phía trên Bounding Box (offset 8px).
   - Thiết kế dạng thanh pill mềm mại, bóng đổ thanh lịch, các nút chạm cảm ứng rộng rãi:
     - **`[ ⟳ Phát quay ]`**: Chuyển đổi giữa đồ thị phẳng 2D và khối tròn xoay 3D.
     - **`[ Góc nhìn: Sách GK ▾ ]`**: Cho phép chọn góc nhìn phối cảnh SGK hoặc các hình chiếu.
     - **`[ ✎ Sửa ]`**: Mở nhanh thanh sửa thông số.
     - **`[ ⧉ Nhân bản ]`**: Tạo bản sao của hình bên cạnh.
     - **`[ 🗑 Xóa ]`**: Xóa hình khỏi bảng.
   - Khi chạm ra ngoài mặt bảng (Deselect): Bounding Box và Floating Context Bar tự động ẩn đi, chỉ giữ lại hình vẽ phấn thanh thoát trên bảng.

