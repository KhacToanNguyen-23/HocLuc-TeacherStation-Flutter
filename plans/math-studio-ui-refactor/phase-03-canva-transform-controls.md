# Phase 3: Canva-Style Transform Controls & Selection State trên Bảng Phấn

## Goal
Nâng cấp trải nghiệm đối tượng trên mặt bảng phấn Flutter: Chuyển đổi từ khung card cố định sang **Transform Controls chuẩn Canva**: Bình thường hình vẽ hoàn toàn trong suốt, không viền, không header; khi chạm/click chọn mới xuất hiện Bounding Box với 8 chốt co giãn (4 góc tỉ lệ, 4 cạnh co giãn), 1 cuống xoay đỉnh và Floating Action Bar.

## Target Files
- `frontend/lib/features/studio_board/domain/models/studio_state.dart`
- `frontend/lib/features/studio_board/presentation/interactive_chalkboard.dart`
- `frontend/lib/features/studio_board/presentation/board_sticker_card.dart`
- `frontend/lib/features/studio_board/domain/models/board_sticker.dart`

## Detailed Implementation Steps
1. **Bổ sung Selection State trong StudioState:**
   - Thêm `String? _selectedStickerId;`
   - Getter: `String? get selectedStickerId => _selectedStickerId;`
   - Method: `void selectSticker(String? id)` thông báo listener khi thay đổi.
2. **Cập nhật InteractiveChalkboard:**
   - Tap vào vùng trống trên mặt bảng (Background Tap) $\rightarrow$ gọi `widget.studio.selectSticker(null)` để bỏ chọn (Deselect).
   - Tap vào đối tượng sticker $\rightarrow$ gọi `widget.studio.selectSticker(s.id)` để kích hoạt trạng thái chọn (Select).
3. **Thiết kế lại BoardStickerCard theo chuẩn Canva:**
   - Nhận thêm cờ `isSelected = (studio.selectedStickerId == sticker.id)`.
   - **Khi `!isSelected` (Bình thường):**
     - Nền 100% trong suốt.
     - Ẩn hoàn toàn viền, ẩn 8 chốt kéo, ẩn cuống xoay, ẩn header bar và floating bar.
     - Hình vẽ nằm tự nhiên tuyệt đối trên mặt bảng phấn xanh.
   - **Khi `isSelected` (Đang chọn):**
     - Hiển thị viền Bounding Box màu cam ấm nét đứt `#D97706`.
     - 4 chốt góc vuông tròn trắng viền cam: Co giãn tỷ lệ đồng dạng (Proportional Scale).
     - 4 chốt giữa các cạnh: Co giãn tự do theo chiều ngang / dọc.
     - 1 cuống xoay tròn trên đỉnh: Kéo chuột xoay tự do góc $\theta \in [0^\circ, 360^\circ]$.
     - Thanh Floating Action Bar lơ lửng trên đỉnh: `[ ✎ Sửa ]`, `[ ⟳ Phát quay ]`, `[ ⧉ Nhân bản ]`, `[ 🗑 Xóa ]`.
4. **Hỗ trợ góc xoay Rotation trong BoardSticker:**
   - Bổ sung trường `double rotation` (mặc định = 0.0) vào model `BoardSticker` và `copyWith`.
   - Bọc nội dung trong `Transform.rotate(angle: sticker.rotation, ...)`.

## Acceptance Criteria
- [ ] Chạm vào vùng trống của bảng làm ẩn toàn bộ viền và thanh công cụ của sticker.
- [ ] Chạm vào sticker hiển thị đầy đủ 8 chốt co giãn và cuống xoay chuẩn Canva.
- [ ] Kéo chốt góc co giãn tỷ lệ, kéo chốt cạnh co giãn 1 chiều, kéo cuống xoay hình vẽ mượt mà.
- [ ] Không còn thanh header card xấu xí che hình vẽ.

