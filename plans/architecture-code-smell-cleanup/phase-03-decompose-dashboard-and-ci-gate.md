# Phase 03: Phân Rã `classroom_dashboard_screen.dart` (1,522 dòng) & Chốt Chặn CI Chống God Class

- **Covers:** Story 3 (P1) — Phân rã `classroom_dashboard_screen.dart` & Chốt chặn CI chống God Class
- **Target Files:**
  - `frontend/lib/screens/classroom_dashboard_screen.dart` (Giảm từ `1,522 dòng` xuống `<860 dòng`: Giữ khung màn hình Dashboard, danh sách giáo án soạn trước và điều hướng)
  - `frontend/lib/screens/classroom_dashboard_rooms_and_history.dart` (Mới — ~675 dòng: Danh sách phòng học trực tuyến `_buildRoomListCard()`, lịch sử buổi học `_buildHistoryCard()`, xuất PDF handout/slides và xóa lịch sử)
  - `frontend/test/architecture_test.dart` (Bổ sung **Bất biến 6**: Kiểm tra mọi file `.dart` trong `frontend/lib/` $\le 1,200$ dòng và mọi file `.java` trong `backend/api/src/main/java/` $\le 600$ dòng)

## Các Bước Thực Hiện
1. Tạo `frontend/lib/screens/classroom_dashboard_rooms_and_history.dart` với `part of 'classroom_dashboard_screen.dart';` chứa `extension _ClassroomDashboardRoomsAndHistoryExt on _ClassroomDashboardScreenState`.
2. Khai báo `part 'classroom_dashboard_rooms_and_history.dart';` trong `classroom_dashboard_screen.dart`.
3. Cập nhật `frontend/test/architecture_test.dart` bổ sung `Bất biến 6: Không có God File vượt quá ngưỡng dòng code tối đa (Dart <= 1200 dòng, Java <= 600 dòng)`.

## Tiêu Chí Nghiệm Thu (Verification)
- `flutter test test/architecture_test.dart test/visual_restyle_test.dart` pass 100%.
- `flutter analyze --no-fatal-infos` đạt 0 lỗi.

