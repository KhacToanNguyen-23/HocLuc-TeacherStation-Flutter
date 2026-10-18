# Feature Specification: Tái Kiến Trúc Sâu Thư Mục `frontend/` (Zero Logic Change)

**Slug**: `frontend-deep-architecture-cleanup`  
**Created**: 2026-10-18  
**Status**: Approved  
**Brainstorm Report**: `plans/reports/261018-frontend-deep-architecture-cleanup-brainstorm.md`

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Dọn Sạch Dead Code, Duplicate Models, Tàn Dư RAM & Vỏ Thư Mục Rỗng (Priority: P1)

Là một kỹ sư phát triển trên `frontend/`, tôi cần kho mã nguồn không còn các tệp mixin/widget/model bị bỏ hoang từ các lần refactor cũ, không còn thư mục con rỗng trong `lib/services/`, và `InstalledPlugin` tuân thủ tuyệt đối quy tắc không giữ `Map<String, Uint8List>` trong RAM.

**Why this priority**: Loại bỏ ngay 1,063 dòng code chết và 17 tệp thừa/vỏ rỗng giúp giảm nhiễu nhận thức (cognitive load) và ngăn chặn lỗi import nhầm model trùng tên (`BoardStroke`, `ImportedDocument`).

**Independent Test**: Chạy `flutter analyze --no-fatal-infos` và kiểm tra không còn bất kỳ tệp `.dart` mồ côi nào trong `frontend/lib/`.

**Acceptance Scenarios**:

1. **Given** 10 tệp mồ côi/trùng lặp (`studio_stage_mixin.dart`, `studio_canvas_mixin.dart`, `studio_timer_mixin.dart`, `studio_pip_mixin.dart`, `board_stroke.dart`, `imported_document.dart`, `studio_lessons_drawer.dart`, `in_board_extension_bar.dart`, `platform_utils.dart`, `lobby_screen.dart`), **When** xóa khỏi kho mã nguồn, **Then** toàn bộ ứng dụng và bộ test biên dịch thành công 100%.
2. **Given** 7 thư mục con chỉ chứa 1 file barrel 3 dòng trong `lib/services/` (`audio/`, `core/`, `exam/`, `google/`, `media/`, `meet/`, `plugins/`), **When** gộp trực tiếp các lệnh `export` vào `lib/services/services.dart` và xóa 7 thư mục vỏ rỗng, **Then** mọi tệp đang `import '.../services/services.dart'` hoạt động bình thường không cần sửa đổi.
3. **Given** `InstalledPlugin` trong `lib/services/plugin_manager.dart`, **When** xóa trường `final Map<String, Uint8List> files`, **Then** `InstalledPlugin` chỉ đọc tài nguyên từ `installDirectory` theo đúng Bất biến #4 của `AGENTS.md`.

---

### User Story 2 - Phân Rã 5 Tệp `> 900 Dòng` Còn Lại Xuống `< 900 Dòng` (Priority: P1)

Là một kỹ sư bảo trì `frontend/`, tôi cần 5 tệp lớn cuối cùng (`pdf_dgnl_passage_overlay.dart`, `meet_automation_service.dart`, `studio_screen.dart`, `region_snipping_overlay.dart`, `pdf_annotation_exporter.dart`) được chia nhỏ hợp lý xuống `< 900 dòng` mà không làm thay đổi bất kỳ logic hay giao diện nào.

**Why this priority**: Đưa toàn bộ 100% tệp `.dart` trong `frontend/lib/` xuống dưới ngưỡng `900 dòng/file`.

**Independent Test**: Chạy `flutter test test/architecture_test.dart test/studio_test.dart test/exam_integration_test.dart` và `flutter analyze --no-fatal-infos`.

**Acceptance Scenarios**:

1. **Given** `pdf_dgnl_passage_overlay.dart` (`1,167 dòng`), `meet_automation_service.dart` (`1,067 dòng`), `studio_screen.dart` (`1,022 dòng`), `region_snipping_overlay.dart` (`976 dòng`), và `pdf_annotation_exporter.dart` (`953 dòng`), **When** tách theo ranh giới chức năng bằng `part` / `part of`, **Then** mỗi tệp đều `< 900 dòng` và giữ nguyên 100% logic.

---

### User Story 3 - Khóa Chặt Cổng Kiến Trúc CI (`<= 900 Dòng`, Cấm Dead File & Cấm RAM Map) (Priority: P1)

Là kiến trúc sư trưởng của dự án, tôi cần `frontend/test/architecture_test.dart` tự động chặn đứng mọi PR tạo ra file `.dart > 900 dòng`, tạo ra file `.dart` mồ côi không được import/part, hoặc tái đưa `Map<String, Uint8List> files` vào `InstalledPlugin`.

**Why this priority**: Đảm bảo các chuẩn mực kiến trúc được thực thi tự động trên GitHub Actions CI.

**Independent Test**: Chạy `flutter test test/architecture_test.dart`.

**Acceptance Scenarios**:

1. **Given** `frontend/test/architecture_test.dart`, **When** hạ ngưỡng `maxDartLines` của Bất biến 6 xuống `900` và thêm Bất biến 7 (kiểm tra Không Có Orphaned Files & Không Có RAM `files` Map trong `InstalledPlugin`), **Then** toàn bộ 7 bất biến trong `architecture_test.dart` đều PASS.

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Xóa 10 tệp Dead Code / Duplicate Models và 7 thư mục barrel vỏ rỗng trong `lib/services/` (cập nhật `lib/services/services.dart` để export trực tiếp).
- **FR-002**: Xóa trường `Map<String, Uint8List> files` khỏi `InstalledPlugin` trong `lib/services/plugin_manager.dart`.
- **FR-003**: Phân rã 5 tệp `.dart > 900 dòng` (`pdf_dgnl_passage_overlay.dart`, `meet_automation_service.dart`, `studio_screen.dart`, `region_snipping_overlay.dart`, `pdf_annotation_exporter.dart`) xuống `< 900 dòng` bằng `part` / `part of`.
- **FR-004**: Nâng cấp `frontend/test/architecture_test.dart`: hạ trần `maxDartLines` xuống `900 dòng` (Bất biến 6) và bổ sung Bất biến 7 kiểm tra không có file `.dart` mồ côi trong `lib/` và không có `Map<String, Uint8List>` trong `InstalledPlugin`.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Số lượng tệp `.dart > 900 dòng` trong `frontend/lib/` giảm từ **5 tệp** xuống **0 tệp** (giảm 100%).
- **SC-002**: Số lượng tệp Dead Code / Orphaned `.dart` trong `frontend/lib/` giảm từ **10 tệp** (`1,063 dòng`) xuống **0 tệp**.
- **SC-003**: Số lượng thư mục con vỏ rỗng trong `frontend/lib/services/` giảm từ **7 thư mục** xuống **0 thư mục**.
- **SC-004**: `flutter test test/architecture_test.dart` đạt **7/7 bất biến PASS** và `flutter analyze --no-fatal-infos` trên toàn bộ các tệp đã chỉnh sửa đạt **0 lỗi / 0 cảnh báo**.

