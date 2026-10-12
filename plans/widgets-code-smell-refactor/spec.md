# Spec: Tái Cấu Trúc Code Smell & Dọn Dẹp Widget Tree (frontend/lib/widgets)

**Date:** 2026-10-12  
**Status:** Ready

---

## Problem Statement
Thư mục `frontend/lib/widgets` chứa hơn 1,460 dòng mã chết (dead code / orphaned widgets), tồn tại sai lệch tên gọi gây hiểu lầm nghiêm trọng (`drawer_questions.dart` thực chất là ngăn kéo tài liệu và trang bảng), và 2 God Widgets vượt quá 700 dòng (`drawer_questions.dart` 808 dòng, `studio_inspector_panel.dart` 708 dòng). Ngoài ra, widget `FloatingTimer` đã có test nhưng chưa được mount vào Studio.

---

## User Stories

- **[P1]** Là lập trình viên, tôi muốn loại bỏ toàn bộ 5 file Dead Code (`color_wheel_picker.dart`, `drawer_documents.dart`, `auth_otp_step_view.dart`, `auth_tab_bar.dart`, `google_sign_in_dialog.dart`) để giảm nợ kỹ thuật và giảm dung lượng bundle.
  Accepted when: Không còn file mồ côi nào không được import trong `frontend/lib/widgets`, toàn bộ 45 unit/widget tests tiếp tục PASS 100%.

- **[P1]** Là lập trình viên, tôi muốn đổi tên và tách `drawer_questions.dart` (808 dòng) thành `studio_document_drawer.dart` và các sub-component chuyên biệt (`studio_document_pages_list.dart`, `studio_document_files_list.dart`) để mã nguồn phản ánh đúng nghiệp vụ và dễ bảo trì.
  Accepted when: `DrawerQuestions` được thay thế bằng `StudioDocumentDrawer`, không file nào trong drawer vượt quá 350 dòng.

- **[P1]** Là lập trình viên, tôi muốn bóc tách `studio_inspector_panel.dart` (708 dòng) thành 2 sub-panel độc lập (`studio_meet_cockpit_tab.dart` và `studio_notes_settings_tab.dart`) để tách biệt rõ luồng tương tác Meet trực tiếp và cấu hình bài giảng.
  Accepted when: `studio_inspector_panel.dart` giảm xuống còn ~150 dòng đóng vai trò coordinator, các tab con tách biệt rõ ràng.

- **[P2]** Là giáo viên sử dụng Studio, tôi muốn có đồng hồ đếm giờ (`FloatingTimer`) hiển thị trực tiếp trên Studio để đếm ngược thời gian làm bài của học sinh.
  Accepted when: `FloatingTimer` được mount vào `StudioScreen` với vị trí linh hoạt, không crash runtime và đáp ứng test `floating_accessories_test.dart`.

- **[P2]** Là lập trình viên, tôi muốn chuẩn hóa toàn bộ các mã màu `Color(0x...)` còn sót lại trong các widget trên sang `AppColors` trong `constants/theme.dart`.
  Accepted when: Không còn mã màu hardcoded trong các file widget đã refactor.

---

## Functional Requirements

1. **FR-01 (Dead Code Elimination):** Xóa bỏ an toàn 5 file:
   - `frontend/lib/widgets/color_wheel_picker.dart`
   - `frontend/lib/widgets/drawer_documents.dart`
   - `frontend/lib/widgets/auth/auth_otp_step_view.dart`
   - `frontend/lib/widgets/auth/auth_tab_bar.dart`
   - `frontend/lib/widgets/lobby/google_sign_in_dialog.dart`
2. **FR-02 (Document Drawer Renaming & Decoupling):**
   - Đổi tên `drawer_questions.dart` thành `studio/studio_document_drawer.dart`.
   - Bóc tách danh sách trang (`StudioDocumentPagesList`) và danh sách tệp PDF (`StudioDocumentFilesList`).
   - Cập nhật import và khởi tạo trong `stage_container.dart`.
3. **FR-03 (Inspector Panel Decoupling):**
   - Bóc tách tab Meet Cockpit sang `studio/studio_meet_cockpit_tab.dart`.
   - Bóc tách tab Cài đặt & Ghi chú sang `studio/studio_notes_settings_tab.dart`.
4. **FR-04 (Mount FloatingTimer to Studio):**
   - Tích hợp `FloatingTimer` vào `StudioScreen` (chỉ hiển thị khi `studio.timerRunning` hoặc khi giáo viên mở đồng hồ từ thanh công cụ).
5. **FR-05 (Design Tokens Alignment):**
   - Thay thế toàn bộ mã màu hexa thô sang `AppColors`.

---

## Non-Functional Requirements

- **Kích thước file:** Không file nào trong `frontend/lib/widgets` vượt quá 450 dòng.
- **Tính toàn vẹn (Zero Regression):** Toàn bộ 45 test case hiện tại trong `flutter test` phải vượt qua 100%.
- **Chất lượng mã nguồn:** `flutter analyze lib` báo cáo 0 cảnh báo, 0 lỗi.

---

## Success Criteria

- [ ] Giảm bớt ít nhất 1,460 dòng Dead Code không dùng tới.
- [ ] Không còn file nào trong `widgets/` vượt quá 500 dòng.
- [ ] `flutter analyze lib` trả về `No issues found!`.
- [ ] `flutter test` đạt `45/45 passed (100%)`.
- [ ] `FloatingTimer` hoạt động trơn tru trong Studio mà không gây lỗi layout.

---

## Out of Scope

- Viết lại canvas vẽ tay `stroke_canvas.dart` (giữ nguyên giải thuật Bezier và stroke renderer).
- Thay đổi cấu trúc dữ liệu `StudioState`.

---

## Assumptions

- `FloatingTimer` đã có sẵn logic đếm giây, start/stop, format MM:SS trong `StudioState` và widget đã sẵn sàng để hiển thị.
- Các file dead code được xác nhận không có bất kỳ thư viện ngoài hay test nào phụ thuộc vào.
