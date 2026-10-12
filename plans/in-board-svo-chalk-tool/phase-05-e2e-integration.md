# Phase 05 — End-to-End Integration & Verification Suite

**Phase ID:** `phase-05-e2e-integration`  
**Mapped Stories:** P1, P2 (Toàn bộ User Stories trong Spec)  
**Status:** `not_started`

---

## 1. Objectives
Tiến hành tích hợp toàn trình (End-to-End) tính năng Khay công cụ bộ môn và Công cụ bóc tách S-V-O phấn màu viết tay. Xây dựng bộ kiểm thử tích hợp toàn diện mô phỏng hành vi giáo viên trong giờ dạy, kiểm thử hồi quy toàn bộ hệ thống và đảm bảo phân tích tĩnh đạt 0 cảnh báo.

---

## 2. Scope & Implementation Details

1. **Bộ Kiểm Thử Toàn Trình (`frontend/test/in_board_svo_e2e_test.dart`):**
   - **Kịch bản 1 (Kích hoạt Dock):** Khi giáo viên kích hoạt tiện ích môn Tiếng Anh, khay dock `SubjectToolPalette` xuất hiện nổi trên bảng phấn với đầy đủ icon S-V-O, nút mắt và nút đóng.
   - **Kịch bản 2 (Chạm chữ viết tay trên bảng):** Chọn công cụ S-V-O và chạm vào vùng có nét chữ viết tay, hệ thống tự động gom nét và sinh ra các nét gạch chân phấn màu $S$ (xanh), $V$ (hồng), $O$ (cam) ngay dưới nét chữ trong $< 400\text{ ms}$.
   - **Kịch bản 3 (Chạm câu trên tệp PDF):** Trong chế độ xem tài liệu PDF, chạm vào dòng chữ tiếng Anh, hệ thống sinh ra gạch chân S-V-O tương ứng trên trang PDF đó.
   - **Kịch bản 4 (Ẩn / Hiện đáp án):** Bấm nút mắt trên dock, toàn bộ ký hiệu S-V-O trên bảng và PDF ẩn đi ngay lập tức; bấm lần nữa sẽ hiển thị lại nguyên vẹn.
   - **Kịch bản 5 (Kéo thả di chuyển & Lưu trữ):** Kéo thả cụm ký hiệu S-V-O đến vị trí khác, lưu bài giảng sang file `.hls` (JSON), sau đó nạp lại bài giảng và xác nhận toàn bộ vị trí/màu sắc/dữ liệu của các chú thích được bảo toàn 100%.
   - **Kịch bản 6 (Đóng tiện ích):** Bấm nút đóng dock, bảng phấn trở về trạng thái bình thường mà không làm mất các nét phấn đã gạch.

2. **Kiểm Thử Hồi Quy Toàn Bộ Hệ Thống:**
   - Chạy toàn bộ test suite hiện có (47 tests gốc + các unit/widget tests mới của 5 phase).
   - Đảm bảo các tính năng cốt lõi: Inking canvas, pan/zoom, PDF annotations, split stage switcher, camera PIP không bị bất kỳ ảnh hưởng nào.

3. **Kiểm Tra Phân Tích Tĩnh (Static Analysis):**
   - Chạy `flutter analyze` trên toàn bộ dự án, đạt kết quả `No issues found!`.

---

## 3. Files Affected
- `frontend/test/in_board_svo_e2e_test.dart` *(Tạo mới)*
- `feature_list.json` *(Cập nhật trạng thái hoàn thành các phase)*

---

## 4. Dependencies
- Phụ thuộc vào cả 4 phase trước (Phase 01, Phase 02, Phase 03, Phase 04).

---

## 5. Tests & Acceptance Criteria
- [ ] Chạy lệnh `flutter test test/in_board_svo_e2e_test.dart` pass 100%.
- [ ] Chạy toàn bộ test suite `flutter test` pass 100% không có test nào bị fail hoặc bỏ qua.
- [ ] Chạy `flutter analyze` đạt 0 issues.
- [ ] Thời gian xử lý từ lúc chạm đến khi nét phấn xuất hiện $\le 400\text{ ms}$.

---

## 6. Risks & Notes
- Đảm bảo dọn dẹp các Timer hoặc Listener khi chuyển trang hoặc đóng dock để tránh memory leak.
