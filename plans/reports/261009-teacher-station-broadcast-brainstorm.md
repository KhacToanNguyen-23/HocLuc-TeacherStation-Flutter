# Brainstorm: Teacher Station Broadcasting

**Date:** 2026-10-09

## Ideas Explored
- **Share Window (Screen Share):** Giáo viên mở ứng dụng, dùng tính năng Share Screen của Google Meet để chia sẻ bài giảng. (Dễ nhất nhưng trải nghiệm không mượt).
- **Nhúng Google Meet (WebView):** Tiêm thẳng Google Meet vào app và đưa luồng hình ảnh lên qua trình duyệt nhúng.
- **Virtual Camera & Virtual Microphone (Được chọn):** Ứng dụng tự mix toàn bộ bảng trắng, công cụ giáo viên và camera thành một luồng video duy nhất, đóng vai trò như một Camera Ảo. Google Meet chỉ làm nhiệm vụ chịu tải.

## User's Direction
Người dùng mong muốn ứng dụng đóng vai trò như một "Studio trộn hình ảnh và âm thanh". Ứng dụng không chỉ lọc tiếng ồn hay hình ảnh đơn thuần, mà các tính năng hỗ trợ giáo viên và bảng trắng phải được stream thẳng lên Google Meet như một luồng camera ảo. Google Meet chỉ đóng vai trò là endpoint để chịu tải và hiển thị cho học sinh, giống mô hình phát sóng của OBS Studio hoặc vMix.

## Open Questions
- Kỹ thuật trộn hình (Compositing): Liệu team sẽ tự code native C++ để capture màn hình hay sẽ nhúng engine của OBS Studio để tạo Camera Ảo? Vấn đề này đã được tạm gác lại để lấy Spec trước.
- Sự tương tác của học sinh: Do bảng trắng bị biến thành Video truyền qua Meet, chưa rõ học sinh có cần công cụ riêng để tương tác ngược lại không hay chỉ tiếp nhận một chiều.

## Risks
- Đòi hỏi phải tích hợp các thư viện C++ mức thấp (Native Virtual Camera/Microphone) vào Java Service.
- Khó khăn trong việc cài đặt driver Camera Ảo trên máy của người dùng cuối (yêu cầu quyền Admin, có thể bị Windows Defender cảnh báo nếu thiếu chứng chỉ số).
