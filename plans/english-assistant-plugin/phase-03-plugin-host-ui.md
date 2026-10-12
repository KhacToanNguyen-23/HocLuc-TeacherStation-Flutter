# Phase 03: Hybrid Plugin Host UI (Drawer Panel 420px & Pop-out Floating Window)

**Canonical Phase ID:** `phase-03-plugin-host-ui`  
**Stories Covered:** P1 (Drawer Panel 420px, Ghim thẻ), P2 (Nút Pop-out thành Floating Window)  
**Priority:** P1  

---

## Objective
Dựng giao diện khung chứa Plugin đa nền tảng: Mặc định là một Drawer Panel trượt ra từ cạnh phải với bề rộng 420px, có nút **[🗗 Pop-out]** để tách thành Cửa sổ nổi tự do (`FloatingPluginWindow`), tích hợp `FlatHost` và cầu nối giao tiếp hai chiều (Bridge Message) để nhận lệnh `INSERT_ANNOTATION`.

---

## Scope & Implementation Tasks

1. **Tạo widget `PluginHostDrawer` (`frontend/lib/widgets/plugin_host_drawer.dart`):**
   - Thiết kế dạng trượt mượt mà (AnimatedPositioned) từ cạnh phải của màn hình stage.
   - Chiều rộng 420px theo khai báo `default_width` trong manifest.
   - Header gồm:
     - Biểu tượng và tên plugin (`Trợ giảng Tiếng Anh`).
     - Nút **[🗗 Tách cửa sổ / Pop-out]** để chuyển sang chế độ cửa sổ nổi.
     - Nút **[✕]** để đóng panel.
   - Body nhúng `FlatHost` nạp trang `ui/index.html` của plugin.

2. **Tạo widget `FloatingPluginWindow` (`frontend/lib/widgets/floating_plugin_window.dart`):**
   - Tương tự như `FloatingPdfWindow` và `FloatingPip`:
     - Có thanh kéo di chuyển vị trí tự do khắp màn hình (`onPanUpdate`).
     - Nút **[🗖 Gắn lại vào ngăn kéo]** để quay lại Drawer Panel.
     - Nút thu nhỏ / đóng cửa sổ.

3. **Cơ chế Cầu nối (Bi-directional Bridge Handler):**
   - Mở rộng hoặc lắng nghe message từ `FlatHost`:
     - Khi nhận `{ "action": "INSERT_ANNOTATION", "payload": ... }`:
       - Tạo một `BoardSticker` mới với dữ liệu S-V-O và lỗi ngữ pháp từ payload.
       - Gọi `studio.addSticker(...)`.
       - Hiển thị SnackBar thông báo: *"Đã ghim thẻ phân tích S-V-O lên bảng phấn"*.
       - Tự động thu gọn panel nếu giáo viên đang để chế độ auto-collapse.

4. **Tích hợp vào `StageContainer` & `DrawerQuestions`:**
   - Trong [drawer_questions.dart](file:///d:/6_OJT/HocLuc-TeacherStation-Flutter/frontend/lib/widgets/drawer_questions.dart), phần TIỆN ÍCH MÔN HỌC hiển thị danh sách plugin đã cài đặt.
   - Bấm vào plugin sẽ kích hoạt mở `PluginHostDrawer` trên [stage_container.dart](file:///d:/6_OJT/HocLuc-TeacherStation-Flutter/frontend/lib/widgets/stage_container.dart).

---

## Files Affected
- `frontend/lib/widgets/plugin_host_drawer.dart` (new)
- `frontend/lib/widgets/floating_plugin_window.dart` (new)
- `frontend/lib/widgets/drawer_questions.dart`
- `frontend/lib/widgets/stage_container.dart`
- `frontend/test/plugin_ui_test.dart` (new)

---

## Dependencies
- Phụ thuộc Phase 01 (`BoardSticker`) và Phase 02 (`PluginManifest`).

---

## Tests and Acceptance Criteria
- Chạy `flutter test test/plugin_ui_test.dart`:
  - Panel Drawer mở ra với chiều rộng 420px.
  - Bấm nút Pop-out chuyển trạng thái sang `FloatingPluginWindow`.
  - Giả lập message `INSERT_ANNOTATION` kích hoạt thêm đúng 1 `BoardSticker` vào `StudioState`.
