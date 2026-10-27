# Phase 3: Frontend Local Session Recording & Resumable Drive Upload

**Status:** Not Started  
**Spec Coverage:** P1 (Story 1, Story 2), FR-01, FR-02  
**Package:** `frontend/lib/features/classroom_meet/services/`

---

## 🎯 Goal
Xây dựng module ghi hình buổi dạy siêu nhẹ (Studio Board canvas + Mic giáo viên) trực tiếp trên Teacher Station Desktop (Flutter Windows), và cơ chế tự động tải lên Google Drive của lớp học qua Resumable Upload chống rớt mạng.

---

## 🛠️ Tasks

1. **Lightweight Screen & Audio Capture (`SessionRecordingService`):**
   - Sử dụng package `record` (đã có trong pubspec) hoặc native Windows Media Foundation để thu âm micro chất lượng giọng nói rõ ràng (Mono AAC 64 kbps).
   - Tối ưu cấu hình quay canvas bảng vẽ Studio Board:
     - 12–15 FPS (đủ mượt cho nét chữ viết bảng và slide, giảm 75% dung lượng so với 60 FPS).
     - Định dạng H.264 MP4.
     - Dung lượng mục tiêu: $\le 120$ MB cho buổi học 60 phút.
   - Quản lý vòng đời ghi hình:
     - Tự động bắt đầu khi giáo viên bấm "Bắt đầu buổi dạy" (hoặc qua nút Record trên toolbar).
     - Ghi liên tục vào file tạm trong `%LOCALAPPDATA%/HocLuc/recordings/` để nếu máy sập nguồn vẫn không mất dữ liệu.

2. **Chunked Resumable Drive Upload (`GoogleDriveUploadService`):**
   - Triển khai giao thức **Google Drive API v3 Resumable Upload**:
     - Bước 1: Khởi tạo session upload với metadata file (tên file, thư mục cha `teacherFolderId` của lớp).
     - Bước 2: Tải file theo từng chunks 5MB–10MB qua HTTP PUT.
     - Bước 3: Lắng nghe tiến độ phần trăm (`progress` 0% $\rightarrow$ 100%).
     - Tự động khôi phục (Resume) từ chunk bị gián đoạn nếu rớt mạng.
   - Gán quyền chia sẻ cho học sinh: Gọi `drive.permissions.create` đặt `role: reader` cho domain/học sinh trong khóa học.

3. **Background Worker & System Tray Status:**
   - Khi giáo viên bấm "Kết thúc buổi dạy", hiển thị popup xác nhận:
     `"Buổi học đã kết thúc (Thời lượng: 60 phút, 85MB). Tải lên Drive lớp và phân tích ĐGNL?"`
   - Quá trình upload chạy ngầm êm ái, hiển thị thanh tiến độ nhỏ ở góc dưới màn hình hoặc system tray.

---

## 🧪 Verification
- Widget & Unit test `SessionRecordingServiceTest`: Kiểm tra start/stop recording, ghi file tạm hợp lệ.
- Unit test `GoogleDriveUploadServiceTest`: Mock HTTP server kiểm tra Resumable Upload chunks và resume logic khi mất kết nối.
- Đảm bảo giới hạn file Dart $\le 900$ LOC và tuân thủ Pure Clean Architecture.

