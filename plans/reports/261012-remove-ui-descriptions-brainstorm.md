# Brainstorm: Rà soát & Loại bỏ toàn bộ Description (UI Subtitle & Guidance Text)

**Date:** 2026-10-12
**Status:** Completed

---

## Ideas Explored

1. **Option A: Toàn diện cả UI lẫn source code comments:** Xóa toàn bộ subtitle/helper text trên giao diện người dùng đồng thời dọn sạch các docstrings (`///`, `//`) trong code. (Dismissed: Gây ảnh hưởng bảo trì mã nguồn, người dùng chỉ muốn tinh gọn giao diện người dùng).
2. **Option B: Tinh giản nhẹ UI (Giữ lại hint/placeholder text):** Xóa các đoạn văn mô tả ngoài form nhưng vẫn giữ hint text và subtitle ngắn.
3. **Option C: Ultra-Minimalist UI (Selected):** Xóa toàn bộ các subtitle, đoạn giải thích, helper banner rườm rà trên Dashboard, Lobby, Dialogs, và Studio. Chỉ giữ lại Icon, Tiêu đề chính ngắn gọn, và Nút bấm hành động trực quan (chuẩn trải nghiệm chuyên nghiệp như Zoom / Google Meet).

---

## User's Direction

- **Phạm vi:** Toàn bộ các dòng chữ mô tả phụ trên giao diện (UI subtitles, đoạn văn giải thích/hướng dẫn dài dòng trên Dashboard, Lobby, Studio, Dialogs).
- **Phong cách:** **Ultra-minimalist** — Chỉ giữ lại Icon, Tiêu đề chính và Nút hành động; loại bỏ triệt để các subtitle, đoạn văn giải thích thừa thãi gây rối mắt.

---

## Key Areas to Audit & Refactor

1. **Classroom Dashboard (`classroom_dashboard_screen.dart` & `dashboard_action_card.dart`):**
   - Loại bỏ hiển thị subtitle trong `DashboardActionCard`.
   - Giữ nguyên các nút hành động cốt lõi: Tham gia, Bắt đầu, Lên lịch.
   - Bỏ các dòng văn bản giải thích trong `DashboardEmptyCard`.
   - Lịch sử phòng học: hiển thị gọn gàng thời gian/trạng thái không kèm câu văn dẫn dắt dài dòng.
2. **Lobby (`classroom_lobby_screen.dart`, `lobby_meet_room_card.dart`):**
   - Bỏ banner cảnh báo rườm rà *"Chưa có phòng Meet thật. Bấm tạo link mới để học sinh có thể tham gia."* (chỉ giữ badge trạng thái gọn gàng "Chưa có link" / "Sẵn sàng").
   - Bỏ đoạn giải thích dài dòng trong Dialog dán link Google Meet.
   - Bỏ đoạn text cảnh báo dài dòng trong dialog khi chưa có link Meet, chỉ giữ tiêu đề và các nút lựa chọn.
3. **Dialogs (`join_classroom_dialog.dart`, `schedule_classroom_dialog.dart`):**
   - Bỏ câu text *"Dán link Google Meet của lớp học hoặc nhập mã phòng (vd: abc-defg-hij):"*.
   - Input field hiển thị trực tiếp dưới tiêu đề.
4. **Studio & Settings Drawer (`studio_notes_settings_tab.dart`, etc.):**
   - Bỏ các text subtitle như *"Loại bỏ tiếng ồn quạt & bàn phím"*, chỉ giữ label tính năng và công tắc/slider.

---

## Open Questions

- Không còn câu hỏi bị chặn. Đã thống nhất phong cách Ultra-minimalist.

---

## Risks

1. **Nguy cơ vỡ widget test:** Một số widget test có thể đang `find.text(...)` các câu chữ mô tả cũ. Cần rà soát và cập nhật test tương ứng sau khi dọn text.
2. **Trải nghiệm người dùng mới:** Thiếu các câu văn hướng dẫn có thể làm người dùng mới chưa quen, tuy nhiên giao diện mô phỏng Google Meet quen thuộc với giáo viên nên rủi ro thấp.
