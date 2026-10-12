# Phase 01 — Subject Tool Palette Dock

**Phase ID:** `phase-01-subject-tool-palette`  
**Mapped Stories:** P1 (Subject Tool Dock), P2 (Eye Toggle Button)  
**Status:** `not_started`

---

## 1. Objectives
Xây dựng khay công cụ bộ môn dạng dock nổi (`SubjectToolPalette`) thanh mảnh, gắn liền trên mặt bảng phấn, thay thế hoàn toàn thanh gõ câu văn thô cứng `InBoardExtensionBar`. Khay dock cung cấp các nút kích hoạt công cụ chuyên môn (bắt đầu bằng công cụ S-V-O), nút con mắt bật/tắt hiển thị đáp án, và nút đóng dock.

---

## 2. Scope & Implementation Details

1. **State Management trong `StudioState`:**
   - Thuộc tính `String? activeSubjectTool`: Lưu công cụ bộ môn đang được kích hoạt (ví dụ: `'svo'` hoặc `null`).
   - Thuộc tính `bool chalkAnnotationsVisible = true`: Trạng thái ẩn/hiện toàn bộ lớp đáp án ký hiệu phấn màu trên bảng và tài liệu.
   - Thuộc tính `Offset subjectPaletteOffset = const Offset(24, 20)`: Vị trí kéo thả tự do của dock trên màn hình bảng.
   - Các phương thức điều khiển:
     - `void setActiveSubjectTool(String? tool)`: Kích hoạt / bỏ chọn công cụ.
     - `void toggleChalkAnnotationsVisibility()`: Đảo ngược trạng thái ẩn/hiện đáp án.
     - `void setSubjectPaletteOffset(Offset offset)`: Cập nhật tọa độ kéo thả dock.

2. **Widget `SubjectToolPalette` (`frontend/lib/widgets/subject_tool_palette.dart`):**
   - Thiết kế dạng dock nổi bo tròn tinh tế (`BorderRadius.circular(24)`), viền kính mờ (`Color(0xf0162620)`), đổ bóng mềm mại không che khuất bài giảng.
   - Cho phép giáo viên kéo thả (`GestureDetector.onPanUpdate`) di chuyển khay dock đến bất kỳ góc nào thuận tiện trên bảng.
   - Bao gồm các thành phần:
     - **Subject Badge:** Icon môn học + Tên tiện ích (ví dụ: `Tiếng Anh`).
     - **S-V-O Tool Button:** Icon cú pháp với hiệu ứng phát sáng khi active (`Color(0xff89b4fa)`), tooltip `Công cụ bóc tách S-V-O (Chạm vào câu)`.
     - **Eye Toggle Button:** Icon `Icons.visibility` / `Icons.visibility_off`, tooltip `Ẩn/Hiện đáp án S-V-O`.
     - **Clear Annotations Button:** Icon xóa nhanh các chú thích S-V-O trên trang hiện tại.
     - **Close Button:** Đóng khay dock môn học (`studio.closePlugin()`).

3. **Tích hợp vào `StageContainer` (`frontend/lib/widgets/stage_container.dart`):**
   - Thay thế `InBoardExtensionBar` bằng `SubjectToolPalette` khi `studio.activePlugin != null`.
   - Đảm bảo vị trí dock nổi không bị che khuất bởi các thanh công cụ hệ thống.

---

## 3. Files Affected
- `frontend/lib/widgets/subject_tool_palette.dart` *(Tạo mới)*
- `frontend/lib/models/studio_state.dart` *(Cập nhật thuộc tính & hàm điều khiển dock)*
- `frontend/lib/widgets/stage_container.dart` *(Cập nhật hiển thị dock)*
- `frontend/test/subject_tool_palette_test.dart` *(Kiểm thử widget dock & toggle state)*

---

## 4. Dependencies
- Phụ thuộc vào `StudioState` và `activePlugin`.
- Là nền tảng cho Phase 02, 03, 04 nhận biết khi nào công cụ S-V-O đang được bật.

---

## 5. Tests & Acceptance Criteria
- [ ] Chạy lệnh `flutter test test/subject_tool_palette_test.dart` pass 100%.
- [ ] Mở plugin Tiếng Anh, `SubjectToolPalette` hiển thị mượt mà trên góc bảng, không còn thanh gõ text cũ.
- [ ] Bấm nút S-V-O, trạng thái `studio.activeSubjectTool` đổi thành `'svo'`; bấm lần nữa trở về `null`.
- [ ] Bấm nút con mắt, `studio.chalkAnnotationsVisible` đảo trạng thái giữa `true` và `false`.
- [ ] Kéo thả dock bằng chuột/cảm ứng, tọa độ `subjectPaletteOffset` cập nhật mượt mà.
- [ ] Bấm nút đóng, dock biến mất và `activePlugin` được giải phóng.

---

## 6. Risks & Notes
- Dock không được bắt cứng kích thước khiến tràn màn hình trên các thiết bị nhỏ: Thiết lập giới hạn co giãn tự động và clamping tọa độ trong khung nhìn của `StageContainer`.
