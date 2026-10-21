# Phase 05 — Đăng học liệu Classroom từ app

Trạng thái: đề xuất. Story: P1 upload giáo án/bài giảng/video. Phụ thuộc: 01 và artifact đã duyệt từ 04; tài liệu đơn giản có thể qua cùng cổng sớm hơn.

## Công việc

- Tái sử dụng tài khoản/kết nối Workspace hiện có sau audit scopes, token storage và refresh. App chọn lớp, tiêu đề, nội dung, artifact và trạng thái đăng; trình bày rõ đây là học liệu, không tự chuyển thành bài tập.
- Incremental consent cho `classroom.courseworkmaterials` và `drive.file` khi phù hợp luồng thực; xử lý revoked/expired/missing grants trong app. OAuth native có thể cần browser hệ thống cho cấp quyền, không dùng WebView cookies thay token API.
- Upload Drive resumable, lưu session/offset an toàn, kiểm quyền file theo lớp và attachment thực tế. Tạo `courses.courseWorkMaterials.create`; lưu `courseId/driveFileId/materialId` và link mở lại từ app.
- Publication journal trạng thái upload/create/reconcile/complete; idempotency key theo revision/course/intent, đối chiếu remote sau timeout. API create không có đảm bảo idempotency nội bộ để dựa vào retry mù; định nghĩa correlation và hành động sửa khi không thể kết luận.
- Preflight allowlist artifact, đúng revision đã duyệt, không notes/answer key/private original; preview nội dung và file đúng trước hành động đăng do giáo viên thực hiện.
- Lưu lịch sử xuất bản để cập nhật/chọn đăng bản mới có chủ ý. Cleanup chỉ file app sở hữu, tránh xóa file đã gắn ở học liệu thành công.

## Nghiệm thu

- Tài khoản giáo viên tạo học liệu PDF/MP4 vào đúng lớp từ app; tài khoản học sinh thực mở/xem được file. Không dùng teacher preview để suy ra quyền học sinh.
- Thử thiếu scope, hết token, từ chối quyền, mất mạng khi upload, timeout ngay sau create và app restart: khôi phục được hoặc nêu trạng thái cần xử lý, không âm thầm tạo bản trùng.
- Người không dạy lớp hoặc artifact không thuộc revision không thể đăng; notes sentinel không tồn tại trong attachment/payload.
- Ghi nhận Google IDs, kết quả quyền và lỗi đã thử; không log token, nội dung riêng hoặc secret. Chưa có tài khoản kiểm thử thì gate integration còn mở.

Nguồn hợp đồng: [Classroom create](https://developers.google.com/workspace/classroom/reference/rest/v1/courses.courseWorkMaterials/create), [Drive resumable uploads](https://developers.google.com/workspace/drive/api/guides/manage-uploads), [OAuth native](https://developers.google.com/identity/protocols/oauth2/native-app).
