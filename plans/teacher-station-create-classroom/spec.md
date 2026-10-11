# Spec: UI Tạo Lớp Học & Quản Lý Phát Sóng (1-Click Classroom & Stream Control)

**Date:** 2026-10-10
**Status:** Approved

---

## Problem Statement
Giáo viên cần một quy trình tạo lớp học trực tuyến cực nhanh (1-Click), tự động tạo link Google Meet và cho phép chia sẻ ngay cho học sinh, đồng thời giữ toàn quyền kiểm soát thời điểm bắt đầu phát sóng (Stream ON/OFF) bảng trắng.

---

## User Stories

- **[P1]** As a Giáo viên, I want to bấm nút "Tạo lớp học" trên thanh trên cùng (TopBar) so that hệ thống tự động sinh link Google Meet mà không bắt tôi phải điền biểu mẫu phức tạp.
  Accepted when: Bấm nút mở ra modal hiển thị tiến trình và link Meet `meet.google.com/xxx-yyyy-zzz` sau vài giây.

- **[P1]** As a Giáo viên, I want to có nút "Sao chép link" ngay trên modal tạo lớp so that tôi gửi nhanh qua Zalo/nhóm phụ huynh.
  Accepted when: Bấm nút sao chép đưa link vào clipboard và hiển thị snackbar xác nhận.

- **[P1]** As a Giáo viên, I want to vào bảng trắng chuẩn bị bài trước và chỉ phát sóng khi bấm "Bắt đầu dạy" (ON) so that học sinh không xem được màn hình riêng tư khi tôi chưa sẵn sàng.
  Accepted when: Vào lớp thì màn hình ở trạng thái chưa stream; chỉ khi giáo viên bật "Bắt đầu dạy" / toggle ON thì luồng Virtual Camera mới bắt đầu gửi khung hình lên Meet.

- **[P2]** As a Giáo viên, I want to xem trạng thái phát sóng rõ ràng (Chờ dạy vs Đang phát sóng LIVE) trên bảng trắng so that tôi biết học sinh đã nhìn thấy bài giảng hay chưa.
  Accepted when: Badge hiển thị trực quan giữa "Sẵn sàng (Chưa phát)" và "LIVE (Đang phát sóng)".

---

## Functional Requirements

1. FR-01: Thanh công cụ trên cùng (`studioTopBar`) bổ sung nút `[ + Tạo lớp học ]` nổi bật.
2. FR-02: Modal `CreateClassroomDialog`:
   - Hiển thị spinner khi WebView2 đang điều hướng `meet.google.com/new`.
   - Hiển thị ô link Google Meet kèm nút `Sao chép`.
   - Hiển thị nút `[ Vào lớp ngay ]`.
3. FR-03: Không tự động kích hoạt `WgcBroadcaster.startBroadcast()` khi vừa tạo lớp.
4. FR-04: Trên giao diện Whiteboard Studio, thanh điều khiển có nút bật/tắt: `[ ▶ Bắt đầu dạy ]` (hoặc switch ON/OFF). Khi bật mới gọi `startBroadcast()`. Khi tắt gọi `stopBroadcast()`.

---

## Non-Functional Requirements

- Performance: Thời gian sinh link Meet < 5 giây (phụ thuộc đường truyền).
- Usability: Thao tác tạo lớp và lấy link chỉ tốn 2 cú nhấp chuột (1 click tạo, 1 click copy link).

---

## Success Criteria

- [ ] Click-to-Link: Giáo viên tạo lớp và lấy link trong đúng 1 bước.
- [ ] Privacy Control: Màn hình không bị stream lên Meet cho đến khi giáo viên bấm "Bắt đầu dạy".

---

## Out of Scope
- Quản lý điểm danh học sinh tự động trong phase này.
- Phân loại môn học / thời khóa biểu phức tạp.

---

## Assumptions
- WebView2 Runtime đã có sẵn trên máy Windows của giáo viên.
