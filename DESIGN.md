---
name: HocLucStation
description: Implemented restrained blue–slate appearance for the existing teaching
  station.
colors:
  primary: '#0369A1'
  primaryHover: '#075985'
  primaryPressed: '#0C4A6E'
  onPrimary: '#FFFFFF'
  background: '#F8FAFC'
  surface: '#FFFFFF'
  surfaceMuted: '#F1F5F9'
  textPrimary: '#0F172A'
  textSecondary: '#475569'
  textMuted: '#64748B'
  border: '#CBD5E1'
  inputBorder: '#64748B'
  selected: '#E0F2FE'
  onSelected: '#075985'
  success: '#047857'
  successSurface: '#ECFDF5'
  warning: '#92400E'
  warningSurface: '#FFFBEB'
  error: '#B91C1C'
  errorSurface: '#FFF1F2'
  overlaySurface: '#0F172A'
  overlayRaised: '#1E293B'
  overlayMuted: '#CBD5E1'
  chalkboard-bg: '#14221D'
  chalk-ink-default: '#F0F3ED'
typography:
  title:
    fontFamily: Manrope
    fontSize: 18px
    fontWeight: 700
  title-compact:
    fontFamily: Manrope
    fontSize: 16px
    fontWeight: 700
  body:
    fontFamily: Manrope
    fontSize: 13px
  body-small:
    fontFamily: Manrope
    fontSize: 11px
  label:
    fontFamily: Manrope
    fontSize: 12px
    fontWeight: 700
  button-primary:
    fontFamily: Manrope
    fontSize: 14px
    fontWeight: 700
  button-secondary:
    fontFamily: Manrope
    fontSize: 14px
    fontWeight: 600
  button-auth:
    fontFamily: Manrope
    fontSize: 13px
    fontWeight: 700
  tab-selected:
    fontFamily: Manrope
    fontSize: 14px
    fontWeight: 700
  tab-idle:
    fontFamily: Manrope
    fontSize: 14px
    fontWeight: 600
  action-title:
    fontFamily: Manrope
    fontSize: 16px
    fontWeight: 700
    letterSpacing: -0.2px
  brand-mark:
    fontFamily: Literata
    fontSize: 20px
    fontWeight: 700
rounded:
  control: 8px
  panel: 12px
  badge: 6px
spacing:
  xs: 4px
  sm: 8px
  md: 12px
  lg: 16px
  xl: 20px
  xxl: 24px
  xxxl: 32px
components:
  button-primary:
    backgroundColor: '{colors.primary}'
    textColor: '{colors.onPrimary}'
    typography: '{typography.button-primary}'
    rounded: '{rounded.control}'
    padding: 0px 18px
    height: 40px
  button-secondary:
    backgroundColor: '{colors.surface}'
    textColor: '{colors.textPrimary}'
    typography: '{typography.button-secondary}'
    rounded: '{rounded.control}'
    padding: 0px 16px
    height: 40px
  button-auth:
    backgroundColor: '{colors.primary}'
    textColor: '{colors.onPrimary}'
    typography: '{typography.button-auth}'
    rounded: '{rounded.control}'
    height: 44px
  input-default:
    backgroundColor: '{colors.surface}'
    textColor: '{colors.textPrimary}'
    typography: '{typography.body}'
    rounded: '{rounded.control}'
    padding: 12px 12px
  input-auth:
    backgroundColor: '{colors.surface}'
    textColor: '{colors.textPrimary}'
    typography: '{typography.body}'
    rounded: '{rounded.control}'
    padding: 12px 14px
  nav-dashboard-selected:
    backgroundColor: '{colors.selected}'
    textColor: '{colors.onSelected}'
    typography: '{typography.tab-selected}'
    rounded: '{rounded.panel}'
    padding: 11px 20px
  nav-dashboard-idle:
    textColor: '{colors.textSecondary}'
    typography: '{typography.tab-idle}'
    rounded: '{rounded.panel}'
    padding: 11px 20px
  chip-count-selected:
    backgroundColor: '{colors.selected}'
    textColor: '{colors.onSelected}'
    typography: '{typography.label}'
    rounded: '{rounded.badge}'
    padding: 2.5px 8px
  card-action:
    backgroundColor: '{colors.surface}'
    textColor: '{colors.textPrimary}'
    typography: '{typography.action-title}'
    rounded: '{rounded.panel}'
    padding: 20px 24px
  card-exam:
    backgroundColor: '{colors.surface}'
    textColor: '{colors.textPrimary}'
    rounded: '{rounded.panel}'
    padding: '{spacing.xxl}'
  tool-selected:
    backgroundColor: '{colors.selected}'
    textColor: '{colors.onSelected}'
---

# Design System: HocLucStation

## Overview

**Creative North Star: "HocLucStation"**

HocLucStation là trạm hỗ trợ giáo viên chuẩn bị bài, giảng dạy và ôn thi. Diện mạo đã triển khai dùng xanh dương–slate tiết chế, bề mặt sáng và chữ rõ; tính cách đồng hành, rõ ràng, đáng tin cậy được thể hiện qua khả năng nhận biết công cụ và trạng thái. Tên hiển thị trong ứng dụng, cửa sổ Windows và web là HocLucStation; dấu chữ nhận diện là “H”.

Đặc tả này ghi nhận source Flutter sau lượt thay diện mạo đã được duyệt. Vị trí, kích thước vùng làm việc và luồng điều hướng giữ theo giao diện hiện có; ảnh dashboard được duyệt chỉ định hướng màu, viền và phân cấp chữ. Minh họa đăng nhập, icon Material, font bundle và hệ màu nội dung bảng được tái sử dụng.

**Key Characteristics:**

- Desktop trước; giữ các breakpoint và mật độ thao tác hiện có.
- Nền sáng, bề mặt trắng, hành động xanh đậm; overlay studio dùng slate tối.
- Bề mặt phẳng và bo góc vừa phải; trạng thái chọn rõ, không nhấc thẻ khi hover.
- Manrope cho UI, Literata tại dấu nhận diện hiện có; bảng phấn có palette riêng.

**The Current Layout Rule.** Giữ vị trí, kích thước vùng làm việc, thứ tự điều khiển, breakpoint và luồng thao tác khi thay diện mạo.

Nguồn chuẩn: `frontend/lib/theme/app_palette.dart`, `app_theme.dart`, `app_visuals.dart`, `constants/theme.dart` và style tại screen/widget. Giá trị “px” trong YAML biểu diễn Flutter logical pixels. Kích thước trong component là biến thể được ghi nhận, không phải kích thước bắt buộc cho mọi nút.

## Colors

**The Semantic Color Rule.** Dùng màu theo vai trò từ AppPalette; xanh dành cho hành động/lựa chọn, xanh lá cho thành công, nâu cho cảnh báo, đỏ cho lỗi và hành động nguy hiểm.

**The Canvas Boundary Rule.** Không áp palette chrome lên màu nét bút, bảng phấn, PDF hoặc nội dung do giáo viên chọn.

- `primary`, `primaryHover`, `primaryPressed`: nền nút chính; chữ `onPrimary`.
- `background`, `surface`, `surfaceMuted`: nền trang, thẻ, vùng phụ; `textPrimary`, `textSecondary`, `textMuted` phân cấp nội dung và placeholder.
- `border` dành cho phân cách trang trí; `inputBorder` dành cho đường biên điều khiển cần nhận biết.
- `selected`/`onSelected` dành cho tab và công cụ đang chọn. Các cặp success, warning, error chỉ mô tả trạng thái thật.
- Overlay giảng dạy dùng slate tối đặc, chữ trắng/slate sáng; không có lớp kính xanh tím trang trí.
- Nút chính disabled dùng `textMuted` làm nền và chữ trắng để spinner/nhãn hiện có dễ đọc. Các nút semantic riêng tiếp tục diễn đạt trạng thái tương ứng.

Các cặp chữ chuẩn được kiểm tra tỷ lệ tương phản bằng test màu thực tế; đây không phải chứng nhận WCAG toàn ứng dụng. Màu thương hiệu Google và nội dung minh họa không bị thay bằng palette chrome.

## Typography

**The Readable Hierarchy Rule.** Giữ kích thước chữ hiện có; dùng màu và độ đậm để phân cấp, không tạo thêm tiêu đề trang trí.

Manrope bundle là font UI; Literata chỉ giữ tại dấu nhận diện. Body gốc (13px), body nhỏ (11px), tiêu đề thường (18px, 700), tiêu đề compact (16px, 700), nhãn (12px, 700). Action card (16px, 700; compact 14px) giữ line break và constraints hiện có. Không tải font mạng hoặc đổi cỡ chữ đồng loạt.

## Elevation

**The Flat Surface Rule.** Thẻ và nút thường không có bóng trang trí; độ nổi chỉ thể hiện lớp phủ thật.

Control bo nhẹ (8px), panel (12px), badge nhỏ (6px); vòng tròn và pill mang chức năng vẫn được giữ. Dialog/menu và inspector có Material elevation thấp (4). Một số lớp phủ dùng bóng giới hạn blur (8px); CSS preview chỉ xấp xỉ blur Flutter. Viền focus không phải bóng trang trí.

## Components

**The Visible State Rule.** Hover và pressed đổi màu tại chỗ; focus phải nhìn thấy được và không dịch chuyển vùng bấm.

- **Nút chính:** nền xanh, chữ trắng, hover/pressed từ AppTheme; các style cục bộ không ghi đè màu nền chính cố định. Nút viền dùng đường biên nhận biết rõ và focus đậm.
- **Input:** nền trắng, placeholder slate, viền trung tính; focus xanh, lỗi đỏ. Giữ padding, chiều cao và hành vi nhập hiện có.
- **Tab/badge/tool:** trạng thái chọn xanh nhạt và chữ xanh đậm, không dùng bóng để nâng tab.
- **DashboardActionCard:** chuột và bàn phím kích hoạt cùng callback, focus nhìn thấy; hover/pressed không di chuyển card hoặc mũi tên.
- **Studio/lobby:** giữ bảng, toolbar, preview và panel tại chỗ. Preview camera tắt chỉ vẽ một lớp thông báo để tránh chồng chữ.
- **Google Workspace và Meet:** màn quản lý lớp/kết nối, thông báo cấp quyền lại và hộp duyệt học sinh dùng cùng palette, bề mặt phẳng và nút kế thừa trạng thái của AppTheme. Hộp duyệt giữ elevation thấp và panel radius; không áp màu của app vào nội dung WebView Google.
- **Microphone Windows:** cụm điều khiển đặt trên nền slate tối đặc, trạng thái mic và mức âm lượng dùng tint ngữ nghĩa đủ sáng. Focus dùng viền sáng; hộp cài đặt giữ nền sáng và input/nút từ theme chung. Chọn thiết bị, mute và volume giữ hành vi của service hiện có.
- **Motion:** phản hồi ngắn; các AnimatedContainer tùy biến dùng AppMotion và tắt duration khi hệ thống yêu cầu giảm chuyển động. Theme button hỗ trợ cùng lựa chọn. Không thêm chuyển động vào engine bảng hoặc video.

Bằng chứng render dùng widget Flutter thật, font bundle và dữ liệu fixture ở 1366×768, 1440×900, 1920×1080, cùng DPR 1.25. So 24 scene chính với baseline, dung sai anchor 1 logical px. Gallery bổ sung có đăng ký, đăng nhập tải/lỗi, panel studio, đề thi rỗng/lỗi và các tab admin. Browser tích hợp không khả dụng; chưa kiểm chứng camera, bút và Google Meet trên thiết bị thật. Chi tiết trong `plans/teacher-station-visual-redesign/implementation.md`.

## Do's and Don'ts

- Do giữ yêu cầu “supportive, clear, and trustworthy” trong PRODUCT.md.
- Do dùng palette và theme chung cho chrome, giữ Manrope, Literata và minh họa đăng nhập hiện có.
- Do kiểm tra render, contrast và geometry khi chỉnh component dùng chung.
- Do giữ nhãn trạng thái cùng màu, tooltip và phím tắt hiện có.
- Don't thêm “visual or interaction choices that make teaching tasks harder to understand or interrupt classroom flow” — anti-reference trong PRODUCT.md.
- Don't đổi bố cục theo ảnh sinh, thêm sidebar hoặc thay điều hướng trong lượt thay diện mạo.
- Don't dùng gradient trang trí, glow, thẻ nhấc khi hover hoặc bo shell quá lớn.
- Don't đổi màu nội dung bảng/PDF hoặc coi fixture camera/Meet là kiểm chứng thiết bị thật.
