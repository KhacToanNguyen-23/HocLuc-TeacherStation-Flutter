# Brainstorm: Định Hình Phong Cách Màu Sắc & Design System (Nordic Sky & Slate Blue)

**Date:** 2026-10-11

## Ideas Explored
1. **Xanh Giáo Dục hiện tại (Deep Pine & Fresh Lime)**: Tông xanh lá cây mộc mạc đã làm mẫu trước đó, nhưng người dùng đã bác bỏ vì muốn tông Xanh Dương rõ ràng.
2. **Xanh Dương Học Thuật Cổ Điển (Academic Royal Blue - #0A2540 / #1E3A8A)**: Tông xanh đậm đại học kiểu Coursera/Oxford.
3. **Xanh Dương Công Nghệ Cao (Tech Ocean & Electric Neon Blue - #0B192C / #00D2FF)**: Tương phản mạnh, phong cách phần mềm hacker/developer.
4. **Xanh Dương Tối Giản & Dịu Mắt (Nordic Sky & Slate Blue - #0F172A / #1E293B / #0284C7 / #38BDF8)**: Lựa chọn trúng đích được người dùng chọn lựa. Mang lại cảm giác tĩnh lặng, hiện đại, chuẩn Scandinavian EdTech, chống mỏi mắt tối đa khi giáo viên đứng lớp hoặc nhìn màn hình thời gian dài.

## User's Direction
- **Màu sắc cốt lõi:** Người dùng xác nhận dứt khoát: *"tôi muốn xanh dương chứ không phải xanh lá"*.
- **Sắc thái cụ thể:** Xanh Dương Tối Giản & Dịu Mắt (**Nordic Sky & Slate**):
  - Primary / Deep Surfaces: Deep Slate (`#0F172A` / `#1E293B`) cho Hero Banner, TopBar, tiêu đề và Sidebar.
  - Interactive Brand Accent / CTA: Nordic Sky Blue (`#0284C7` / `#0EA5E9` / `#38BDF8`) cho các nút chính, trạng thái active, badge nổi bật.
  - Neutral / Canvas Background: Nordic Slate Mist (`#F8FAFC` / `#F1F5F9`) tạo nền mềm mại, không gây chói lóa.
  - Secondary Accents: Soft Amber (`#F59E0B` - lịch hẹn), Soft Emerald (`#10B981` - trạng thái online/hoàn thành), Soft Rose (`#F43F5E` - đăng xuất/lỗi).
- **Kiến trúc mã nguồn Flutter:**
  - Chuẩn hóa thành `ThemeExtension` của Flutter (`AppColorTheme`) để hỗ trợ chuyển đổi Light/Dark Theme mượt mà thông qua `BuildContext` / `Theme.of(context)`.
  - Duy trì các token tĩnh `AppColors` làm fallback hằng số thuận tiện.
- **Phạm vi áp dụng:**
  - Áp dụng toàn bộ hệ thống giao diện: Trang Đăng nhập (`LoginScreen`), Dashboard Lớp học (`ClassroomDashboardScreen`), các Dialogs (`Join`, `Schedule`), và thanh công cụ điều khiển của `StudioScreen`.
  - Riêng mặt bảng vẽ (Canvas) vẫn duy trì các tùy chọn truyền thống (bảng trắng, bảng ô ly) để đảm bảo thói quen giảng dạy tự nhiên của giáo viên.

## Open Questions (For Planning)
1. Cơ chế Dark Mode có bật tự động theo hệ điều hành (System Brightness) hay giáo viên có nút bấm chuyển đổi thủ công trên TopBar?
2. Cách xử lý gradient Hero Banner bên LoginScreen để tạo chiều sâu 3D dịu mắt giữa Slate 900 (`#0F172A`) và Nordic Sky Navy (`#0C4A6E`).

## Risks
1. **Mức độ nhận diện logo "Mộc"**: Tên gọi "Mộc" vốn hay liên tưởng tới cây cối màu xanh lá. Chuyển sang Xanh Dương cần định hình "Mộc" là sự mộc mạc, tĩnh lặng, chân thực và đáng tin cậy (như đá phiến Slate và bầu trời Nordic Sky).
2. **Độ tương phản văn bản**: Cần đảm bảo các mức độ màu Slate (`#0F172A`, `#334155`, `#64748B`) đạt chuẩn WCAG AA/AAA trên nền `#F8FAFC`.
