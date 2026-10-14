# Phase 04 — Studio Planning Mode

**Phase ID:** `phase-04-studio-planning-mode`  
**Priority:** P1  
**Status:** not_started  

---

## Objective
Mở rộng không gian bảng vẽ `StudioScreen` và thanh điều khiển `StudioTopBar` để hỗ trợ chế độ Soạn bài giảng (`isPlanningMode: true`), cho phép giáo viên viết vẽ, chèn tài liệu, lưu bản thảo và bấm nút "Tạo phòng học" trực tiếp từ giao diện bảng.

---

## Scope & Implementation Tasks
1. **Cập nhật `StudioScreen` (`frontend/lib/screens/studio_screen.dart`):**
   - Bổ sung các tham số vào constructor:
     - `bool isPlanningMode = false`
     - `String? planningId`
   - Khi `isPlanningMode: true`:
     - Nếu mở một bài giảng đã có (`planningId != null`): Tải dữ liệu từ `localService.getPlanningContent(planningId)` và nạp vào state bằng `studio.restoreFromJson(content)`.
     - Nếu tạo mới: Khởi tạo bảng trắng sạch với tiêu đề bài giảng đã nhập.
     - Hàm `save()`: Lưu trực tiếp vào API Planning (`updatePlanning` hoặc `createPlanning`) thay vì lưu vào `/api/lesson`.
2. **Cập nhật `StudioTopBar` (`frontend/lib/widgets/studio/studio_top_bar.dart`):**
   - Khi ở `isPlanningMode: true`:
     - **Ẩn thanh Google Meet link**: Thay bằng nhãn huy hiệu tinh tế `[Chế độ soạn bài]` hoặc hiển thị tiêu đề và trạng thái lưu.
     - **Thay đổi nút góc phải**:
       - Ẩn nút đỏ "Rời phòng".
       - Bổ sung nút **"Lưu & Thoát"** (icon `Icons.arrow_back_ios_new_rounded` hoặc `Icons.save_outlined`): Lưu nội dung và quay lại Dashboard.
       - Bổ sung nút hành động chính **"Tạo phòng học"** (màu xanh dương nổi bật `AppColors.sky600`, icon `Icons.videocam_rounded`): Mở dialog tạo phòng học từ bài giảng này.
3. **Mở rộng `StudioState` (`frontend/lib/models/studio_state.dart`):**
   - Thêm phương thức hỗ trợ lưu/nạp dành riêng cho planning: `savePlanning(String? id)` hoặc tích hợp linh hoạt trong `save()`.

---

## Files & Modules Affected
- `frontend/lib/screens/studio_screen.dart` (chỉnh sửa)
- `frontend/lib/widgets/studio/studio_top_bar.dart` (chỉnh sửa)
- `frontend/lib/models/studio_state.dart` (chỉnh sửa)

---

## Dependencies
- Phụ thuộc: `phase-02-frontend-service-and-models` (cần API client lưu planning).

---

## Tests & Acceptance Criteria
- Mở `StudioScreen` với `isPlanningMode: true`:
  - Top bar không hiển thị link Google Meet và không có nút đỏ "Rời phòng".
  - Có nút "Lưu & Thoát" và nút "Tạo phòng học".
  - Giáo viên có thể vẽ trên nhiều trang, chèn stickers, câu hỏi thảo luận, ghi chú, và bấm lưu thành công.
- Khi bấm "Lưu & Thoát", nội dung được cập nhật trên backend và người dùng trở về Dashboard tab "Kế hoạch bài giảng".

---

## Risks & Decisions
- Đảm bảo khi người dùng nhấn phím Back hoặc đóng cửa sổ lúc đang có thay đổi chưa lưu (`dirty == true`), hiển thị cảnh báo xác nhận lưu trước khi thoát.
