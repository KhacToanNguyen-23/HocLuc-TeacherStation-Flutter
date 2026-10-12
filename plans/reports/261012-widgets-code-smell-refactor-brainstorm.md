# Brainstorm: Tái Cấu Trúc Code Smell & Dọn Dẹp Widget Tree (frontend/lib/widgets)

**Date:** 2026-10-12

## Ideas Explored
1. **Xóa bỏ triệt để Dead Code & Widget mồ côi (~1,460 dòng):**
   - Loại bỏ các file hoàn toàn không còn sử dụng hoặc là bản sao thừa:
     - `color_wheel_picker.dart` (510 dòng): 0 tham chiếu trong toàn bộ source và test.
     - `drawer_documents.dart` (522 dòng): Bản sao 100% của ngăn kéo tài liệu, 0 tham chiếu.
     - `auth/auth_otp_step_view.dart` (213 dòng) & `auth/auth_tab_bar.dart` (75 dòng): Thừa sau khi hợp nhất vào `AuthFormCard`.
     - `lobby/google_sign_in_dialog.dart` (143 dòng): Hộp thoại token thủ công cũ, đã thay bằng WebView SSO.
2. **Sửa lỗi Naming Smell & Bóc tách God Widget `drawer_questions.dart` (808 dòng):**
   - Tên file và class là `DrawerQuestions` nhưng nội dung 100% là quản lý trang bài giảng và tệp tài liệu PDF ("Tài liệu giảng dạy").
   - Đổi tên thành `studio_document_drawer.dart` (`StudioDocumentDrawer`) và chia thành:
     - `studio_document_pages_list.dart`: Danh sách thumbnail các trang bảng, thêm trang, reorder.
     - `studio_document_files_list.dart`: Vùng kéo thả desktop drop, danh sách file PDF và popover xóa/mở.
3. **Bóc tách God Widget `studio_inspector_panel.dart` (708 dòng):**
   - Tách thành 2 sub-panel:
     - `studio_meet_cockpit_tab.dart`: Quản lý Google Meet trực tiếp (trạng thái phòng, danh sách giơ tay ✋, duyệt vào phòng, live chat stream và khung gửi tin nhắn).
     - `studio_notes_settings_tab.dart`: Ghi chú bài giảng, câu hỏi trắc nghiệm, endpoint cấu hình và nút xem trước.
4. **Tích hợp FloatingTimer vào StudioScreen:**
   - `floating_timer.dart` (270 dòng) đã có widget test hoàn chỉnh, sẽ được mount lên `StudioScreen` và hiển thị khi bật công tắc đồng hồ làm bài.
5. **Chuẩn hóa Token màu sắc:**
   - Chuyển đổi các mã màu thô `Color(0x...)` trong các widget còn lại sang `AppColors`.

## User's Direction
- Người dùng thống nhất phương án xử lý toàn diện:
  1. Xóa dọn toàn bộ ~1,460 dòng Dead Code không dùng tới.
  2. Bóc tách 2 God Widgets lớn (`drawer_questions.dart` 808 dòng và `studio_inspector_panel.dart` 708 dòng).
  3. Đổi tên chuẩn xác `drawer_questions.dart` thành `studio_document_drawer.dart` (phù hợp đúng chức năng quản lý tài liệu & trang giảng dạy).
  4. Giữ lại `FloatingTimer` và gắn vào `StudioScreen` để giáo viên sử dụng khi đếm giờ học sinh làm bài.

## Open Questions
- Không còn câu hỏi mở. Toàn bộ phạm vi và giải pháp đã được chốt rõ ràng.

## Risks
1. **Phá vỡ test case khi đổi tên Drawer:** Cần kiểm tra xem có test nào tìm theo Type `DrawerQuestions` hay không để cập nhật tương ứng (đã kiểm tra: chỉ có `stage_container.dart` gọi widget này).
2. **Kích thước layout khi gắn FloatingTimer:** Cần đảm bảo `FloatingTimer` sử dụng `SafeClamp` và nằm trong `Stack` của `StudioScreen` để không cản trở bảng vẽ Chalkboard.
