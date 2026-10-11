# Spec: Design System Màu Sắc Nordic Sky & Slate Blue (Học Lực · Mộc)

**Date:** 2026-10-11  
**Status:** Ready  

---

## Problem Statement
Giao diện dự án trước đây sử dụng tông màu xanh lá cây (`Deep Pine #062319` và `Lime #CBFF8F`), chưa đáp ứng đúng định hướng mong muốn của người dùng là **màu xanh dương (Blue)**. Việc chuyển sang hệ màu **Nordic Sky & Slate Blue** chuẩn hóa qua Flutter `ThemeExtension` giúp mang lại không gian làm việc tối giản, thanh lịch, chuẩn EdTech cao cấp và chống mỏi mắt cho giáo viên giảng dạy thời gian dài.

---

## User Stories

- **[P1]** Là một giáo viên, tôi muốn giao diện Login, Dashboard lớp học và thanh công cụ mang tông màu Xanh Dương dịu mắt (Nordic Sky & Slate) để làm việc nhiều giờ không bị lóa mắt hay mệt mỏi thị giác.  
  *Accepted when:* Toàn bộ các màn hình chính (LoginScreen, ClassroomDashboardScreen, Action Cards, Dialogs, Studio Shell) hiển thị thống nhất theo bảng màu Nordic Sky & Slate Blue; 0 thành phần nào còn sót lại màu xanh lá cũ.
- **[P1]** Là một lập trình viên, tôi muốn truy cập các token màu sắc thông qua `Theme.of(context).extension<AppColorTheme>()` (hoặc `AppColors`) để việc phát triển nhất quán và dễ mở rộng.  
  *Accepted when:* File `app_color_theme.dart` và `app_colors.dart` định nghĩa đầy đủ Primary, Accent, Surface, Border, Text, và Semantic tokens; toàn bộ các unit/widget tests kiểm tra theme pass 100%.
- **[P2]** Là một giáo viên, tôi muốn chuyển đổi giữa chế độ Sáng (Light - Nordic Mist) và Tối (Dark - Slate Night) để phù hợp với môi trường phòng dạy (ban ngày hoặc buổi tối).  
  *Accepted when:* Hệ thống `AppColorTheme` hỗ trợ đầy đủ cả `light()` và `dark()` tokens với độ tương phản đạt chuẩn WCAG AA.
- **[P3]** _(Out of scope: Tự động đổi màu theme theo môn học riêng lẻ - Toán, Văn, Anh - lưu cho các phiên bản tương lai)_.

---

## Functional Requirements

1. **FR-01 (Palette Definition):** Định nghĩa bảng mã màu chuẩn Nordic Sky & Slate Blue:
   - `slatePrimary`: `#0F172A` (Slate 900 - Nền hero, header, chữ tiêu đề đậm).
   - `slateSurface`: `#1E293B` (Slate 800 - Khung thứ cấp, card tối).
   - `slateBorder`: `#E2E8F0` (Slate 200 - Viền thẻ, divider).
   - `skyAccent`: `#0284C7` (Sky 600 - Nút CTA chính, hover active).
   - `skyLight`: `#38BDF8` (Sky 400 - Điểm nhấn, badge, icon phụ).
   - `skySurface`: `#E0F2FE` (Sky 100 - Nền badge, container highlight).
   - `canvasBackground`: `#F8FAFC` (Slate 50 - Nền toàn ứng dụng, dịu mắt hơn trắng tinh).
   - `paperSurface`: `#FFFFFF` (Nền thẻ card, modal).
   - `statusAmber`: `#F59E0B` (Lên lịch, cảnh báo nhẹ).
   - `statusEmerald`: `#10B981` (Online, thành công).
   - `statusRose`: `#F43F5E` (Đăng xuất, lỗi).
2. **FR-02 (Flutter ThemeExtension):** Tạo class `AppColorTheme extends ThemeExtension<AppColorTheme>` trong `frontend/lib/theme/app_color_theme.dart`, tích hợp vào `ThemeData` trong `main.dart`.
3. **FR-03 (Token Facade):** Cập nhật `frontend/lib/constants/app_colors.dart` ánh xạ sang hệ màu mới để duy trì tương thích cho các widget gọi tĩnh.
4. **FR-04 (Screen Migration):** Cập nhật giao diện:
   - `LoginScreen`: Hero panel nền gradient Slate `#0F172A` -> `#0C4A6E`, nút CTA Sky Blue `#0284C7`.
   - `ClassroomDashboardScreen`: Header TopBar Slate, 3 Action Cards (Begin nổi bật với Sky Blue, Join & Schedule viền Slate), 2 cột danh sách với minh họa Empty State tông Sky & Slate.
   - `StudioScreen`: Thanh công cụ mang tông Slate & Sky thanh lịch.
   - Dialogs: Cập nhật màu nút và viền modal.
5. **FR-05 (Canvas Exemption):** Bảng vẽ phấn/bút (Drawing Canvas) giữ nguyên các tùy chọn nền quen thuộc (bảng trắng `#FFFFFF`, bảng xanh học đường nếu giáo viên thích viết phấn trắng).

---

## Non-Functional Requirements

- **Contrast Ratio:** Độ tương phản văn bản chính (`#0F172A` trên nền `#F8FAFC` và `#FFFFFF` trên `#0284C7`) đạt chuẩn tối thiểu 4.5:1 (WCAG AA).
- **Code Quality:** `flutter analyze lib` đạt 0 errors, 0 warnings.
- **Test Integrity:** Toàn bộ 22/22 widget & unit tests hiện tại tiếp tục pass 100% sau khi áp dụng theme mới.

---

## Success Criteria

- [ ] Toàn bộ màn hình Login, Dashboard, Dialogs chuyển đổi 100% sang màu Xanh Dương Nordic Sky & Slate Blue.
- [ ] 0 lỗi hiển thị, 0 lỗi tràn viền (overflow).
- [ ] 22/22 bài kiểm thử Flutter pass.
- [ ] `flutter analyze lib` pass không có cảnh báo.

---

## Out of Scope

- Không thay đổi logic xác thực Spring Boot OTP hay cấu trúc database PostgreSQL.
- Không thay đổi các thuật toán WebRTC, vẽ Canvas hay PIP engine.
- Tự động thay đổi màu theo môn học chuyên biệt.

---

## Assumptions

- Giáo viên ưa chuộng tông màu xanh dương dịu mắt (Scandinavian style) hơn là màu xanh dương chói/gắt hoặc màu xanh lá cây.
- Các biểu tượng và minh họa vector SVG dễ dàng tái áp dụng tông màu Sky Blue qua thuộc tính `color` hoặc `ColorFilter`.
