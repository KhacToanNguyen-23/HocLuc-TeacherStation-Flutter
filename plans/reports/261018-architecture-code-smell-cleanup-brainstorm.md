# Brainstorm: Kiểm Toán Kiến Trúc & Xử Lý Code Smell (God Classes / Monolithic Screens)

**Date:** 2026-10-18

## Ideas Explored
- **Phương án A (Zero-Breaking Modularization + CI File Size Gate — Đã chọn):** Chia nhỏ các God Classes và Monolithic Screens lớn nhất trong `frontend/lib/` (`studio_state.dart` 2,112 dòng, `exam_workspace_screen.dart` 1,704 dòng, `classroom_dashboard_screen.dart` 1,522 dòng) thành các module/part/tab độc lập theo miền trách nhiệm (<500 dòng/module con, toàn bộ kho code không còn file nào vượt quá 1,200 dòng), giữ nguyên 100% Public API và cây Widget để không phá vỡ 274 bài test hiện có; đồng thời bổ sung Bất biến #6 vào `architecture_test.dart` để cấm tạo God File mới trên CI.
- **Phương án B (Generic Board Overlay Protocol):** Tách toàn bộ logic S-V-O-A và ĐGNL Tiếng Anh (`english_analyzer.dart`, `dgnl_service.dart`, `pdf_dgnl_passage_overlay.dart`, `smart_chalk_overlay.dart`) ra khỏi Core và thay bằng giao thức chú thích tổng quát qua `HostBridge`. Đã tạm hoãn sang giai đoạn sau để tránh thay đổi hàng loạt bài test cũ cùng lúc.
- **Phương án C (Kết hợp toàn diện A + B trong 1 lần):** Rủi ro phạm vi thay đổi quá lớn trong một PR, khó cô lập lỗi hồi quy hình học (`visual_restyle_test.dart`).

## User's Direction
Người dùng chọn **Phương án A**:
> "Chia nhỏ các file lớn (`studio_state.dart`, `exam_workspace_screen.dart`, `classroom_dashboard_screen.dart`) thành các module/tab <500 dòng + Thêm chốt chặn CI giới hạn kích thước file (An toàn 100% với 274 tests)"

## Open Questions
- Đã làm rõ hoàn toàn. Không còn câu hỏi mở chặn bước lập kế hoạch (`$bb-plan`).

## Risks
1. **Rủi ro lệch tọa độ hình học trong `visual_restyle_test.dart`:** Khi tách các widget con hoặc tab từ `exam_workspace_screen.dart` và `classroom_dashboard_screen.dart`, nếu làm thay đổi cấu trúc `AppBar`, `ChoiceChip`, `ExamCard`, `DashboardActionCard`, `ExamDashboardCard`, hoặc `DashboardEmptyCard`, bài test kiểm tra tọa độ pixel (`visual_restyle_test.dart`) sẽ báo lỗi. Giải pháp: Sử dụng Dart `part` / `part of` hoặc tách các phương thức dựng tab/dialog giữ nguyên 100% cây Widget và kiểu `Type` của các anchor widget.
2. **Rủi ro vỡ `import` ở các file đang dùng `studio_state.dart`:** Hơn 40 file trong `frontend/lib/` và `frontend/test/` đang `import '.../models/studio_state.dart'`. Giải pháp: Sử dụng `part` / `export` trong `studio_state.dart` để mọi file bên ngoài vẫn import `studio_state.dart` bình thường mà không cần sửa bất kỳ dòng import nào.

