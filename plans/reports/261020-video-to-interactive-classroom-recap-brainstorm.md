# Brainstorm: Video-to-Interactive-Classroom-Recap (Trợ Giảng AI Bóc Tách Video Buổi Học Thành Bộ Ôn Tập Google Classroom)

**Date:** 2026-10-20  
**Status:** Completed  
**Slug:** `video-to-interactive-classroom-recap`

---

## 1. Problem Context & Inspiration
* **Inspiration:** Mô hình Multi-Agent Interactive Classroom từ nghiên cứu **THU-MAIC/OpenMAIC** (Đại học Thanh Hoa) về chuyển đổi tài liệu/video thành môi trường học tập tương tác đa phương tiện.
* **Định vị cốt lõi:** Loại bỏ 100% bài toán quản trị/hành chính/báo cáo LMS; tập trung thuần túy vào **Công cụ Công nghệ Trợ Lực Giảng Dạy (Teaching Augmentation Power-Tool)** cho Giáo viên.
* **Nỗi đau thực tế:** 
  - Video buổi học trên Google Meet (45–90 phút) quá dài, loãng thông tin, học sinh không có thời gian xem lại từ đầu đến cuối.
  - Giáo viên không có thời gian soạn lại tóm tắt, phiếu bài tập sau mỗi buổi dạy.
  - Học sinh chỉ tiếp nhận học liệu qua **Google Meet** (trực tiếp) và **Google Classroom** (sau buổi học) — không cài đặt phần mềm riêng.

---

## 2. Ideas Explored & Evaluated

### Ý tưởng 1: Sinh Web Portal Ôn tập Riêng biệt (HocLuc Web Player)
* **Ý tưởng:** Xây dựng một trang web riêng (React/Flutter Web) cho học sinh mở video có chapter, lật bảng vẽ, làm quiz.
* **Phản biện / Đánh giá:** **BÁC BỎ (Scope Creep)**. Đòi hỏi dựng hạ tầng web, database, xác thực học sinh, tốn kém chi phí máy chủ và băng thông streaming video. Học sinh phải nhớ thêm một đường link bên ngoài Google Classroom.

### Ý tưởng 2: Upload Video Lên Kênh YouTube Unlisted
* **Ý tưởng:** Tận dụng YouTube để lưu trữ video miễn phí và dùng tính năng Timestamp Chapters tự động của YouTube.
* **Phản biện / Đánh giá:** **BÁC BỎ LÀM KÊNH MẶC ĐỊNH (Rủi ro kỹ thuật cao)**.
  - Hạn ngạch YouTube Data API v3 mặc định chỉ 10,000 units/ngày $\rightarrow$ Mỗi video upload tốn 1,600 units $\rightarrow$ Tối đa chỉ 6 video/ngày cho cả hệ thống!
  - Dễ bị dính bản quyền âm thanh (Content ID) và chính sách bảo vệ trẻ em (COPPA).
  - Kênh chưa xác minh số điện thoại bị giới hạn video dưới 15 phút.
  - *Kết luận:* Chỉ giữ làm tính năng phụ nếu giáo viên chủ động muốn xuất bản công khai.

### Ý tưởng 3: Tự Động Quay Cục Bộ + Lưu Google Drive của Lớp + Đăng Native Google Classroom (ĐƯỢC CHỌN)
* **Lý do chọn:**
  - **Quay video:** Nền tảng Teacher Station tự quay màn hình Studio Board + Mic của giáo viên (tối ưu sư phạm: 15 FPS, H.264 CRF 26-28, Audio Mono 64kbps $\rightarrow$ video 60 phút chỉ 60MB–100MB). Hoạt động độc lập với mọi loại tài khoản Google (kể cả Gmail miễn phí).
  - **Lưu trữ:** 1-Click tự động upload lên thư mục lớp trên Google Drive cá nhân của giáo viên qua Google Drive API (có sẵn OAuth Token).
  - **AI Engine:** Backend dùng `fileId` stream video từ Drive sang Gemini File API (Gemini 1.5/2.0 Flash) để bóc tách: Timestamps mốc thời gian, Key Takeaways, Quizzes.
  - **Kiểm duyệt (Human-in-the-Loop):** Giáo viên xem trước bản nháp, sửa nhanh mốc thời gian, công thức, đáp án quiz trên Teacher Station trước khi đăng.
  - **Đầu ra 100% Native Google Classroom:** Bài đăng Classroom gồm: Danh sách mốc thời gian trong mô tả + Video Google Drive + File PDF tóm tắt + Google Form trắc nghiệm tự chấm. Học sinh không cần cài bất kỳ phần mềm nào.

---

## 3. User's Confirmed Direction

1. **Khâu Ghi hình (Recording):** Nền tảng HocLuc Teacher Station tự quay màn hình Studio Board + Mic của giáo viên, nén tối ưu dung lượng siêu nhẹ (60MB–100MB/buổi).
2. **Khâu Tải lên (Drive Upload):** Tự động hóa 1-click dùng OAuth2 Google Drive API đưa file vào thư mục lớp học `Classroom / [Tên Lớp]`.
3. **Khâu Phân tích AI (Multimodal Analysis):** Backend Spring Boot nhận `fileId`, truyền stream sang Gemini Flash để trích xuất tri thức sư phạm.
4. **Khâu Kiểm duyệt (Review Gate):** Cung cấp giao diện kiểm tra nhanh mốc thời gian, PDF và đáp án Quiz trên Teacher Station cho giáo viên trước khi xuất bản.
5. **Khâu Xuất bản (Publishing):** Đăng bài trực tiếp lên Google Classroom kèm 3 tệp đính kèm: Video Drive, PDF tóm tắt, Google Form Quiz tự chấm.

---

## 4. Open Questions & Risks Worth Watching

1. **Chất lượng âm thanh micro của giáo viên:** Nếu giáo viên dùng micro rè hoặc lẫn tiếng ồn phòng dạy, độ chính xác của ASR có thể suy giảm. Cần prompt Gemini đối chiếu cả chữ viết trên bảng vẽ để bù đắp.
2. **Quyền hạn Google Forms API:** Cần bổ sung scope `https://www.googleapis.com/auth/forms.body` vào luồng OAuth2 của giáo viên khi đăng nhập để tạo form trắc nghiệm tự động.
3. **Xử lý bất đồng bộ (Async Queue):** Quá trình upload video và phân tích AI mất khoảng 1–2 phút; cần đảm bảo job chạy ngầm an toàn tại Backend, có cập nhật trạng thái rõ ràng trên giao diện giáo viên.

