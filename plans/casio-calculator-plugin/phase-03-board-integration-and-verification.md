# Phase 03: Board SDK Bridge & Architecture Verification

**Goal:** Kiểm tra hiển thị cửa sổ nổi trên Studio Bảng phấn, kiểm thử tương tác ghim kết quả tính toán lên bảng, và xác nhận vượt qua toàn bộ 5/5 bài kiểm tra bất biến kiến trúc.

---

## 1. Scope & Action Items

1. **Hiển thị Floating Window trên Bảng phấn:**
   - Kích hoạt plugin máy tính trong Studio.
   - Xác nhận cửa sổ nổi hiện lên với kích thước gọn gàng, kéo thả di chuyển linh hoạt trên canvas.
   - Thử nghiệm đóng cửa sổ nổi: kiểm tra WebView2 được hủy sạch, giải phóng bộ nhớ.
2. **Kiểm thử Host Bridge & Ghim Bảng:**
   - Kiểm tra plugin gọi `HocLuc.board.insertAnnotation(...)` để dán kết quả tính toán hoặc công thức dạng LaTeX/Sticker lên bảng vẽ.
3. **Chốt chặn kiểm thử kiến trúc (Architecture Gate):**
   - Chạy `flutter test test/architecture_test.dart` từ thư mục `frontend/`.
   - Xác nhận tất cả 5 bất biến kiến trúc đều PASSED:
     1. Không hardcode tên riêng plugin trong `frontend/lib/`.
     2. Không hardcode cổng mạng tĩnh 18888 trong `frontend/lib/`.
     3. Không import chéo trực tiếp từ `frontend/lib/` vào `plugins/`.
     4. Mọi plugin trong `plugins/` phải có `manifest.json` Schema v2 hợp lệ.
     5. Cấp phát cổng động không trùng lặp.

---

## 2. Verification Criteria
- [ ] `flutter test test/architecture_test.dart` đạt 5/5 test PASSED.
- [ ] Không có file tạm hoặc artifact thừa bị bỏ lại trong git working tree.
