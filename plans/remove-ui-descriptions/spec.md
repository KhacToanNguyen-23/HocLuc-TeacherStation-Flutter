# Spec: Rà soát & Loại bỏ Description Rườm Rà trên Toàn Bộ Giao Diện (Ultra-Minimalist UI)

**Date:** 2026-10-12
**Status:** Approved

---

## Problem Statement

Giao diện ứng dụng giáo viên hiện tại chứa nhiều đoạn văn mô tả phụ (subtitles, hướng dẫn sử dụng, banner cảnh báo text dài) gây rối mắt, làm giảm tính chuyên nghiệp và hiện đại tương tự các ứng dụng cao cấp như Google Meet hay Zoom. Cần rà soát toàn bộ dự án và loại bỏ triệt để các phần description thừa này để đạt trải nghiệm Ultra-minimalist: sạch, trực quan, tập trung vào hành động cốt lõi.

---

## User Stories

<!-- P1 = MVP (must ship), P2 = nice-to-have, P3 = future/out-of-scope -->

- **[P1]** As a giáo viên, I want giao diện Classroom Dashboard chỉ tập trung vào các nút hành động cốt lõi (Tham gia, Bắt đầu, Lên lịch) mà không có subtitle thừa thãi, so that màn hình tinh gọn và chuyên nghiệp.
  Accepted when: `DashboardActionCard` không còn hiển thị subtitle; hàng nút hành động giữ thiết kế tối giản, sắc nét.

- **[P1]** As a giáo viên, I want màn hình Classroom Lobby và các Dialog kết nối Meet loại bỏ các đoạn văn mô tả/cảnh báo dài dòng, so that tôi thao tác vào lớp nhanh chóng mà không bị xao nhãng.
  Accepted when:
  - `LobbyMeetRoomCard` loại bỏ banner giải thích màu vàng *"Chưa có phòng Meet thật. Bấm tạo link mới..."*.
  - Dialog "Dán link Google Meet" và dialog xác nhận studio không chứa các đoạn văn giải thích dài dòng.
  - Dialog "Tham gia phòng học" (`JoinClassroomDialog`) và "Lên lịch" (`ScheduleClassroomDialog`) hiển thị trực tiếp trường nhập liệu, bỏ câu hướng dẫn thừa.

- **[P1]** As a giáo viên, I want các cài đặt trong Studio (`StudioNotesSettingsTab`, Drawer) loại bỏ subtitle giải thích dưới các công tắc, so that giao diện điều khiển trong lúc giảng dạy gọn gàng.
  Accepted when: Các `ListTile` trong cài đặt âm thanh/thiết bị không còn thuộc tính `subtitle` mô tả dài dòng.

- **[P2]** As a lập trình viên, I want toàn bộ bộ test `flutter test` tiếp tục pass 100% sau khi tinh gọn text, so that không gây regression hay lỗi giao diện.
  Accepted when: Lệnh `flutter test` chạy thành công không có lỗi phát sinh.

- **[P3]** _(out of scope)_
  - Xóa comments hay Javadoc/Dartdoc trong source code (giữ nguyên để phục vụ bảo trì kĩ thuật).
  - Thay đổi cấu trúc bảng cơ sở dữ liệu hoặc API backend.

---

## Functional Requirements

1. **FR-01 (Dashboard Action Cards & Empties):**
   - Loại bỏ hiển thị `widget.subtitle` trong `DashboardActionCard`.
   - `DashboardEmptyCard`: loại bỏ hiển thị subtitle giải thích dài, giữ lại biểu tượng và tiêu đề ngắn.
2. **FR-02 (Join & Schedule Dialogs):**
   - `JoinClassroomDialog`: Bỏ text `Dán link Google Meet của lớp học hoặc nhập mã phòng (vd: abc-defg-hij):`.
   - `ScheduleClassroomDialog`: Tối giản các nhãn, loại bỏ text phụ.
3. **FR-03 (Lobby & Meet Channel):**
   - `LobbyMeetRoomCard`: Xóa khối `Container` banner màu vàng hiển thị dòng chữ cảnh báo dài khi chưa có link. Chỉ giữ trạng thái bằng badge và các nút hành động (Tạo link mới, Mở Chrome, Dán link).
   - Dialog nhập link Meet trong Lobby: Bỏ câu giải thích `Nhập link hoặc mã phòng Google Meet thật do Google cấp...`.
   - Dialog xác nhận vào studio khi chưa có link: Bỏ đoạn giải thích dài, chỉ để câu hỏi súc tích.
4. **FR-04 (Studio Settings & Drawers):**
   - `StudioNotesSettingsTab`: Bỏ `subtitle: const Text('Loại bỏ tiếng ồn quạt & bàn phím', ...)` ở switch lọc ồn micro.

---

## Non-Functional Requirements

- **Design Aesthetic:** Đạt chuẩn Ultra-minimalist, khoảng trắng hợp lý, không có chữ thừa gây phân tán sự chú ý.
- **Reliability:** 100% widget tests và unit tests tiếp tục pass.
- **Performance:** Không phát sinh widget rebuild thừa, thời gian render UI giữ nguyên hoặc nhẹ hơn.

---

## Success Criteria

- [ ] Toàn bộ UI subtitle, helper text, banner mô tả thừa được gỡ bỏ khỏi Dashboard, Lobby, Dialogs, và Studio Settings.
- [ ] Giao diện các màn hình trở nên tinh giản, sạch đẹp theo chuẩn Ultra-minimalist.
- [ ] Chức năng tạo link thật, tham gia phòng, bắt đầu phòng học hoạt động bình thường 100%.
- [ ] Chạy `flutter test` thành công (toàn bộ tests pass).

---

## Out of Scope

- Bỏ ghi chú / comment kỹ thuật trong code backend hoặc frontend.
- Thay đổi cấu trúc DTO hoặc cơ sở dữ liệu.

---

## Assumptions

- Giáo viên đã quen thuộc với khái niệm liên kết Google Meet và các nút bấm cơ bản nên không cần đoạn văn diễn giải từng bước.
