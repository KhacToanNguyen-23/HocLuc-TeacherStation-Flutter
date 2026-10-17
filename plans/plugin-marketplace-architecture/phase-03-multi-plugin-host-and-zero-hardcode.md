# Phase 03: Quản Lý Đa Phiên (Floating + Lesson) & Xóa Sạch Hardcode trong Core

**Mục tiêu:** Loại bỏ hoàn toàn mọi chuỗi hardcode tên/ID plugin và nghiệp vụ môn học cụ thể trong `frontend/lib/`, đồng thời nâng cấp `StudioState` & `StageContainer` để giáo viên có thể mở **song song** tiện ích cửa sổ nổi (như Máy tính Casio) cùng lúc với tiện ích gắn sâu vào bài giảng (`drawer_panel` / `SubjectToolPalette` động).

**User Stories bao phủ:**
- **[P1]** Giáo viên mở đồng thời cửa sổ nổi Máy tính Casio và tiện ích gắn sâu vào bài giảng mà không bị đóng lẫn nhau hay hiện cửa sổ thừa.
- **[P1]** Xóa bỏ 100% hardcode tên plugin và thanh công cụ môn học trong `frontend/lib/`.

---

## 1. Các Hạng Mục Triển Khai Chi Tiết

1. **Gỡ bỏ Hardcode trong `english_analyzer.dart` (`frontend/lib/services/english_analyzer.dart`) & `process_supervisor.dart`:**
   - Bổ sung hàm `int? getActiveSidecarPort([String? preferredPluginId])` trong `ProcessSupervisor` để trả về cổng của sidecar đang chạy mà không cần gọi cứng tên plugin.
   - Trong `english_analyzer.dart`: Xóa bỏ toàn bộ 3 vị trí hardcode `'com.hocluc.plugin.english'` (dòng 191, 314, 363), thay bằng tham số động `pluginId = 'grammar_annotation'` và `ProcessSupervisor.instance.getActiveSidecarPort()`.

2. **Tái cấu trúc `SubjectToolPalette` thành Khay Công Cụ Động (`frontend/lib/widgets/subject_tool_palette.dart`):**
   - Thay vì vẽ cứng các nút của môn Tiếng Anh cho mọi plugin, `SubjectToolPalette` đọc danh sách công cụ từ `plugin.manifest.contributesTools` (hoặc cấu hình đóng góp mặc định nếu plugin là `drawer_panel` trong bài test cũ).
   - Khi giáo viên bấm vào một nút công cụ do plugin đóng góp:
     - Nếu `action == 'snip_region'`: kích hoạt `studio.startSnipping(target: tool.target)`.
     - Nếu `action == 'toggle_tool'`: bật/tắt `studio.setActiveSubjectTool(tool.id)`.
     - Nếu `action == 'quick_input'`: mở hộp thoại nhập văn bản nhanh theo nhãn/gợi ý khai báo trong `tool`.
     - Nếu `action == 'rpc_event'`: gửi sự kiện qua `HostBridge` tới WebView của plugin.

3. **Hỗ trợ Mở Đa Nhiệm (Cửa sổ nổi Casio + Tiện ích Bài giảng) trong `StudioState` (`frontend/lib/models/studio_state.dart`):**
   - Bổ sung quản lý tách biệt cho cửa sổ nổi (`floatingPlugin`) bên cạnh `activePlugin` (hoặc cho phép `floatingPlugin` hoạt động độc lập với `drawer_panel` plugin):
     - Khi mở một plugin có `uiPlacement == 'floating_window'` (như Máy tính Casio): Gán vào `floatingPlugin` (với kích thước lấy từ `manifest.uiDefaultWidth` × `manifest.uiDefaultHeight`), **không làm đóng** plugin ngăn kéo/bài giảng đang mở.
     - Khi mở một plugin `drawer_panel`: Mở ngăn kéo bên phải và hiển thị `SubjectToolPalette` tương ứng mà **không làm tắt** cửa sổ nổi Casio đang bật.
   - Vẫn giữ tương thích 100% với getter `activePlugin` và `pluginFloating` cho các bài kiểm thử hiện tại.

4. **Xóa Cửa Sổ Nổi Trùng Lặp & Hardcode trong Giao diện Studio:**
   - Trong `frontend/lib/screens/studio_screen.dart` (dòng 900–978): Xóa bỏ khối `Positioned` vẽ cửa sổ nổi rỗng dựa trên `PluginManager().activePlugin` (vì `FloatingPluginWindow` trong `StageContainer` đã đảm nhiệm việc hiển thị WebView thực tế).
   - Trong `frontend/lib/widgets/studio/studio_document_drawer.dart` (dòng 195–266): Xóa bỏ dòng chữ hardcode `'Cài đặt Plugin Mẫu (Trợ giảng Tiếng Anh)'` và lời gọi `installSampleEnglishPlugin()`; chuyển thành danh sách động các tiện ích từ `PluginManager.instance.availablePlugins`.
   - Trong `frontend/lib/services/plugin_manager.dart`: Xóa bỏ các chuỗi lọc cứng `'tiếng anh'` / `'english'` và hỗ trợ đọc ảnh `icon.png` trực tiếp từ thư mục cài đặt của plugin (`File('${installDirectory!.path}/${manifest.iconPath}')`).

---

## 2. Tiêu Chí Nghiệm Thu (Verification Criteria)
- [ ] Không còn bất kỳ chuỗi `'com.hocluc.plugin.english'`, `'english_assistant'`, `'casio'` nào trong `frontend/lib/`.
- [ ] Giáo viên mở được cùng lúc 1 plugin `drawer_panel` và 1 plugin `floating_window` (Casio) trên `StageContainer`.
- [ ] `flutter test test/subject_tool_palette_test.dart test/plugin_ui_test.dart test/in_board_svo_e2e_test.dart` PASSED 100%.

