# Brainstorm: Kiểm Toán & Tái Kiến Trúc Toàn Diện Thư Mục `frontend/` (Zero Logic Change)

**Date:** 2026-10-18

## Ideas Explored
1. **Dọn dẹp triệt để Dead Code & Duplicate Models (`1,063 dòng` thừa):** Xóa 10 tệp mồ côi/trùng lặp (`studio_*_mixin.dart`, `board_stroke.dart`, `imported_document.dart`, `studio_lessons_drawer.dart`, `in_board_extension_bar.dart`, `platform_utils.dart`, `lobby_screen.dart`) đang gây nhiễu cấu trúc và tiềm ẩn lỗi `ambiguous_import`.
2. **Loại bỏ lưu trữ byte trong RAM ở `InstalledPlugin` (`AGENTS.md` Mục 2.4):** Xóa trường `Map<String, Uint8List> files` khỏi `InstalledPlugin` trong `plugin_manager.dart`, đảm bảo 100% tài nguyên plugin chỉ đọc từ đĩa (`installDirectory`).
3. **Chuẩn hóa cấu trúc `lib/services/` và `lib/constants/theme.dart`:** Gom trực tiếp các `export` vào `lib/services/services.dart` và xóa 7 thư mục con "vỏ rỗng" (`audio/`, `core/`, `exam/`, `google/`, `media/`, `meet/`, `plugins/` mỗi thư mục chỉ có 1 file 3 dòng) để cây thư mục phản ánh trung thực kiến trúc thực tế mà không làm gãy bất kỳ câu lệnh `import` nào.
4. **Phân rã tiếp 5 tệp lớn còn lại (`950 – 1,167 dòng`) xuống `<900 dòng`:** Tách `pdf_dgnl_passage_overlay.dart` (`1,167`), `meet_automation_service.dart` (`1,067`), `studio_screen.dart` (`1,022`), `region_snipping_overlay.dart` (`976`), và `pdf_annotation_exporter.dart` (`953`) bằng cơ chế `part` / `part of` cùng thư viện để giữ nguyên 100% hành vi và cây Widget.
5. **Siết chặt cổng kiểm thử kiến trúc CI (`architecture_test.dart`):** Hạ trần kích thước file `.dart` của **Bất biến 6** từ `1,200 dòng` xuống `900 dòng`, đồng thời bổ sung **Bất biến 7** (cấm file `.dart` mồ côi không có tham chiếu và cấm `Map<String, Uint8List> files` trong `InstalledPlugin`).

## User's Direction
Người dùng yêu cầu: *"xử lí tất cả mà không thay đổi logic chỉ tái kiến trúc lại thoi"*.
Toàn bộ 5 nhóm vấn đề sẽ được xử lý đồng bộ với nguyên tắc bất dịch: **Zero Behavior Change & Zero Geometry Drift** (không thay đổi bất kỳ luồng nghiệp vụ, API payload, hay tọa độ pixel nào của UI).

## Open Questions
- Không còn câu hỏi mở (người dùng đã xác nhận phạm vi xử lý toàn bộ với ràng buộc giữ nguyên 100% logic).

## Risks
1. **Rủi ro cảnh báo `@protected` khi tách `State` / `ChangeNotifier` sang `part` file:** Cần khai báo `// ignore_for_file: invalid_use_of_protected_member` ở đầu các tệp `part` có gọi `setState` để `flutter analyze` đạt 0 warnings.
2. **Rủi ro lệch tọa độ trong `visual_restyle_test.dart` khi tách `studio_screen.dart`:** Chỉ tách các phương thức xử lý sự kiện/dialog/helper sang `part` extension, giữ nguyên cấu trúc hàm `build()` và thứ tự Widget để không lệch bất kỳ pixel nào.

