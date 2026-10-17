---
name: "HocLucStation"
description: "Source-derived visual baseline for the teacher preparation and teaching station."
colors:
  sky600: "#0284C7"
  sky100: "#E0F2FE"
  sky50: "#F0F9FF"
  slate900: "#0F172A"
  slate800: "#1E293B"
  slate700: "#334155"
  slate600: "#475569"
  slate500: "#64748B"
  slate400: "#94A3B8"
  slate300: "#CBD5E1"
  slate200: "#E2E8F0"
  slate100: "#F1F5F9"
  slate50: "#F8FAFC"
  surface: "#FFFFFF"
  blue600: "#2563EB"
  blue50: "#EFF6FF"
  amber500: "#F59E0B"
  amber100: "#FEF3C7"
  amber50: "#FFFBEB"
  emerald600: "#059669"
  emerald500: "#10B981"
  emerald50: "#ECFDF5"
  rose600: "#E11D48"
  rose500: "#F43F5E"
  rose50: "#FFF1F2"
  input-fill-observed: "#F6F7F2"
  auth-field-border: "#D1D5DB"
  auth-placeholder: "#9CA3AF"
  leave-room: "#DC2626"
  chalkboard-bg: "#14221D"
  chalk-ink-default: "#F0F3ED"
typography:
  title:
    fontFamily: "Manrope"
    fontSize: "18px"
    fontWeight: 800
  title-compact:
    fontFamily: "Manrope"
    fontSize: "16px"
    fontWeight: 700
  body:
    fontFamily: "Manrope"
    fontSize: "13px"
  body-small:
    fontFamily: "Manrope"
    fontSize: "11px"
  label:
    fontFamily: "Manrope"
    fontSize: "12px"
    fontWeight: 700
  button-primary:
    fontFamily: "Manrope"
    fontSize: "14px"
    fontWeight: 700
  button-secondary:
    fontFamily: "Manrope"
    fontSize: "14px"
    fontWeight: 600
  button-auth:
    fontFamily: "Manrope"
    fontSize: "13px"
    fontWeight: 700
  tab-selected:
    fontFamily: "Manrope"
    fontSize: "14px"
    fontWeight: 700
  tab-idle:
    fontFamily: "Manrope"
    fontSize: "14px"
    fontWeight: 600
  action-title:
    fontFamily: "Manrope"
    fontSize: "16px"
    fontWeight: 800
    letterSpacing: "-0.2px"
  brand-mark:
    fontFamily: "Literata"
    fontSize: "20px"
    fontWeight: 700
rounded:
  auth-control: "6px"
  small: "8px"
  control: "9px"
  badge: "10px"
  panel: "12px"
  card: "16px"
  auth-shell-observed: "24px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "12px"
  lg: "16px"
  xl: "20px"
  xxl: "24px"
  xxxl: "32px"
components:
  button-primary:
    backgroundColor: "{colors.sky600}"
    textColor: "{colors.surface}"
    typography: "{typography.button-primary}"
    rounded: "{rounded.control}"
    padding: "0px 18px"
    height: "40px"
  button-secondary:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.slate700}"
    typography: "{typography.button-secondary}"
    rounded: "{rounded.control}"
    padding: "0px 16px"
    height: "40px"
  button-auth:
    backgroundColor: "{colors.slate900}"
    textColor: "{colors.surface}"
    typography: "{typography.button-auth}"
    rounded: "{rounded.auth-control}"
    height: "44px"
  input-default:
    backgroundColor: "{colors.input-fill-observed}"
    textColor: "{colors.slate900}"
    typography: "{typography.body}"
    rounded: "{rounded.control}"
    padding: "12px 12px"
  input-auth:
    backgroundColor: "{colors.input-fill-observed}"
    textColor: "{colors.slate900}"
    typography: "{typography.body}"
    rounded: "{rounded.auth-control}"
    padding: "12px 14px"
  nav-dashboard-selected:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.sky600}"
    typography: "{typography.tab-selected}"
    rounded: "{rounded.panel}"
    padding: "11px 20px"
  nav-dashboard-idle:
    textColor: "{colors.slate700}"
    typography: "{typography.tab-idle}"
    rounded: "{rounded.panel}"
    padding: "11px 20px"
  chip-count-selected:
    backgroundColor: "{colors.sky50}"
    textColor: "{colors.sky600}"
    typography: "{typography.label}"
    rounded: "{rounded.badge}"
    padding: "2.5px 8px"
  card-action-observed:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.slate900}"
    typography: "{typography.action-title}"
    rounded: "{rounded.card}"
    padding: "20px 24px"
  card-exam:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.slate900}"
    rounded: "{rounded.card}"
    padding: "{spacing.xxl}"
  tool-selected:
    backgroundColor: "{colors.sky100}"
    textColor: "{colors.sky600}"
---

# Design System: HocLucStation

## Overview

**Creative North Star: "HocLucStation"**

HocLucStation là trạm hỗ trợ giáo viên chuẩn bị bài, giảng dạy và ôn thi, với tính cách “đồng hành, rõ ràng, đáng tin cậy” đã được xác nhận trong PRODUCT.md. Hệ hiện tại kết hợp bề mặt sáng sky/slate, chữ Manrope và vùng bảng phấn tối. Tên HocLucStation được dùng cho tài liệu này theo yêu cầu người dùng; nhãn runtime hiện tại vẫn là “Mộc · Teaching Studio”.

Đây là bản ghi hiện trạng từ source code, không phải thiết kế đích của lượt redesign. Chưa có đối chiếu rendered/computed styles vì Browser không kết nối được. Giá trị YAML là mốc trích xuất cho đúng component/phạm vi được ghi; trạng thái do Material 3 tự giải quyết không được coi là đã đo. Kế hoạch tại plans/teacher-station-visual-redesign/plan.md mô tả thay đổi diện mạo đang chờ xác nhận; không áp dụng chúng ngược vào bản ghi này.

**Key Characteristics:**

- Desktop trước; hỗ trợ chuột, bàn phím và bút theo các luồng hiện có.
- Nền sáng và một họ màu tương tác chủ đạo; bảng phấn có palette nội dung riêng.
- UI tương đối dày, nhiều nhãn và dữ liệu; typography theo kích thước cố định.
- Chưa có một bộ component thị giác thống nhất cho mọi màn hình.

**The The Current Layout Rule.** Giữ vị trí, kích thước vùng làm việc, thứ tự điều khiển, breakpoint và luồng thao tác của hiện trạng khi thay diện mạo.

Nguồn chính: `frontend/lib/main.dart`, `constants/theme.dart`, `theme/app_color_theme.dart`, `pubspec.yaml`; các component dưới `widgets/auth/`, `widgets/dashboard/`, `widgets/lobby/`, `widgets/studio/`, `widgets/exams/` và các screen tương ứng. Flutter logical pixels được biểu diễn bằng “px” trong frontmatter để trao đổi tài liệu; không phải pixel vật lý Windows.

## Colors

Palette hiện tại dùng xanh trời cho nhiều hành động giảng dạy, slate cho nội dung và một số hành động chính. Các slug giữ tên token gốc để tra lại mã; tên diễn giải là mô tả, không phải đổi tên API.

### Primary

- **Xanh trời tương tác** (`sky600`): nút “Dạy ngay”, đường viền chọn tab, icon và nhiều điểm nhấn đang hoạt động.
- **Xanh trời nhạt** (`sky100`, `sky50`): nền công cụ đang chọn, badge và vùng nhấn nhẹ.
- **Slate đậm** (`slate900`): `ColorScheme.primary` ở root và nền nút đăng nhập. Đây là sự khác biệt có thật với nút sky được style tại chỗ.
- **Xanh dương liên kết** (`blue600`, `blue50`): liên kết/quên mật khẩu và một số badge hoặc điểm nhấn riêng. Chưa hợp nhất với họ sky.

### Neutral

- **Mực slate** (`slate900`, `slate800`, `slate700`): chữ chính, nhãn đậm và icon.
- **Slate phụ** (`slate600`, `slate500`, `slate400`): chữ thứ cấp, metadata, icon mờ. Không coi mọi tổ hợp màu này là đã đạt contrast.
- **Viền và lớp nền** (`slate300`, `slate200`, `slate100`, `slate50`, `surface`): viền, divider, lớp phụ, nền trang và bề mặt trắng.
- **Nền input kế thừa** (`input-fill-observed`): tông trắng ngả nhẹ đang được root `InputDecorationTheme` sử dụng; không phải đề xuất màu nhận diện mới.
- **Ngoại lệ đăng nhập** (`auth-field-border`, `auth-placeholder`): màu hardcode riêng cho viền và hint text; cần kiểm tra tương phản trong lượt tinh chỉnh.

### Semantic and teaching content

- **Hổ phách** (`amber500`, `amber100`, `amber50`): lịch/thời gian và cảnh báo ở các nơi đang dùng.
- **Emerald** (`emerald600`, `emerald500`, `emerald50`): trạng thái tích cực/thành công.
- **Rose** (`rose600`, `rose500`, `rose50`): lỗi và hành động phá hủy; nút rời lớp có token riêng `leave-room` từ giá trị hardcode đang dùng.
- **Bảng phấn** (`chalkboard-bg`) và **mực phấn mặc định** (`chalk-ink-default`): nguồn lần lượt là `widgets/grid_painter.dart` và `models/studio_state.dart`. Không áp lại palette chrome lên học liệu.

**The The Canvas Boundary Rule.** Không thay màu nền bảng, màu nét bút hoặc nội dung PDF chỉ vì chúng khác palette chrome của ứng dụng.

`AppColorTheme.dark()` tồn tại nhưng root hiện chỉ đăng ký preset light. `skyHover` và các giá trị mở rộng không được tự xem là màu hover đang dùng trên mọi nút. Chỉ trích các primitive có vai trò được quan sát; không sao chép toàn bộ hằng số chưa dùng.

## Typography

**UI Font:** Manrope, bundle trong `assets/fonts/Manrope.ttf`.
**Brand Mark Font:** Literata, bundle trong `assets/fonts/Literata.ttf`; dấu “m” hiện dùng các biến thể nhỏ theo vị trí.
**Fallback in sidecar previews:** sans-serif/serif của trình duyệt nếu chưa nạp font; không phải font fallback đã cấu hình trong Flutter.

Hệ chữ phục vụ nhãn, công cụ và dữ liệu, không có thang display thống nhất. Frontmatter giữ các vai trò có giá trị rõ từ source; body không thêm weight hay line-height chưa được khai báo.

- `title`: tiêu đề khối đề thi; `title-compact`: tiêu đề danh sách kế hoạch.
- `body`, `body-small`: hai kích thước khai báo ở root `TextTheme`.
- `label`: nhãn/badge đếm; `button-primary`, `button-secondary`, `button-auth`: khác nhau theo nút đã quan sát.
- `tab-selected` và `tab-idle`: tab dashboard khác độ đậm và màu.
- `action-title`: tiêu đề action card; bản compact dùng chữ nhỏ hơn (14 logical px), không phải thang body mới.
- `brand-mark`: dấu nhận diện ở dashboard; studio có biến thể nhỏ hơn (18 logical px).

Còn các kích thước tại chỗ như 12.5, 13.5, 14.5 và 15 logical px. Không diễn giải chúng thành một thang tỷ lệ chuẩn đã được áp dụng toàn app. Không có body line-height, letter-spacing hay giới hạn dòng toàn cục được chứng minh ngoài các trường nêu trong YAML.

## Elevation

Hiện trạng là hỗn hợp: một số card chỉ có viền; card danh sách có bóng nhẹ; action card nhấc lên và phát bóng khi hover; shell đăng nhập dùng bóng rộng; panel studio dùng Material elevation. Đây là danh mục hiện trạng, không phải đề nghị nhân rộng các hiệu ứng đó.

- **Action card nghỉ:** offset (0, 2), blur (6), spread (0), đen alpha (0.03).
- **Action card hover:** offset (0, 7), blur (18), spread (1), sky600 alpha (0.18); dịch dọc (-3).
- **Card rỗng/kế hoạch:** offset (0, 3), blur (10), đen alpha (0.02).
- **Hàng kế hoạch:** offset (0, 1), blur (4), đen alpha (0.015).
- **Tab được chọn:** offset (0, 2), blur (8), sky600 alpha (0.08).
- **Shell đăng nhập:** offset (0, 14), blur (36), đen alpha (0.08), góc bo theo `auth-shell-observed`.
- **Stage bảng:** offset (0, 4), blur (16), đen alpha (0.2).
- **Panel studio:** Material elevation (16); không tự chuyển thành một bóng CSS “chính xác” vì hai hệ render khác nhau.

Các bóng CSS tương đương để xem trước, motion và breakpoint được đặt trong `.fk-skills/design.json`. Flutter blurRadius và CSS blur không bảo đảm kết quả thị giác giống nhau; chưa đo chúng bằng ảnh chụp app.

## Components

### Buttons

Có hai nhóm primary thực tế. “Dạy ngay” dùng sky, chữ trắng, chiều cao/padding/góc bo theo `button-primary`; “Đăng nhập” dùng slate và `button-auth`. Nút “Soạn tiếp” dùng `button-secondary`, viền slate300 (1.2 logical px). Material elevation của nút dạy (1); nút đăng nhập (0).

Hover/focus/pressed/disabled phần lớn do Material 3 kế thừa từ theme. Source chưa định nghĩa một bộ state token chung; không khẳng định đã có màu trạng thái riêng cho mọi nút. Nút loading thay nhãn bằng spinner tại chỗ tùy form.

### Inputs / Fields

`input-default` là cấu hình root: nền filled, viền slate200 và padding theo YAML. `input-auth` thay góc bo, padding, hint và focused border tại chỗ; focused border sky600 (1.5 logical px). Effective border khi enabled/error còn phụ thuộc quy tắc kế thừa `InputDecoration` của Flutter; không suy ra chỉ từ trường `border`.

Auth hint dùng `auth-placeholder`, không phải màu body. Trạng thái lỗi có banner/form feedback riêng. Hiện chưa có một bộ input error/disabled/focus dùng chung được cấu hình tường minh.

### Navigation and chips

Dashboard có tab chọn nền trắng, viền sky600 (1.5 logical px) và bóng chọn; tab chưa chọn nền trong suốt. Chuyển style bằng `AnimatedContainer` (200 ms). Badge đếm theo `chip-count-selected`; trạng thái chưa chọn dùng nền slate200 và chữ slate600.

Hàng tab có scroll ngang theo hiện trạng. Không đổi sang sidebar hoặc nav pattern khác khi thay diện mạo.

### Cards / Containers

- Action card theo `card-action-observed`; viền nghỉ (1.2 logical px), hover (1.5 logical px); icon chứa trong ô (48×48) hoặc compact (40×40). Khi chiều rộng card dưới (220), padding chuyển thành (16 dọc, 12 ngang), gap icon–nhãn (8); bản thường gap (12).
- `card-exam` là khối trắng chỉ có viền slate200; không có bóng khai báo. Shortcut đề thi có góc bo theo `badge`, padding (16 dọc, 12 ngang), min-height (48).
- Card rỗng có header padding (12 dọc, 20 ngang), nội dung padding theo `spacing.xxl`; card kế hoạch còn nhiều padding tại chỗ. Không coi chúng là một component card duy nhất đã chuẩn hóa.
- Scale `AppSpacing` trong YAML đã được dùng tại dashboard; các giá trị tại chỗ (6, 10, 11, 14, 18, 28…) vẫn còn. Không tự đổi chúng trong lệnh trích spec.

### Studio tools and presentation stage

Thanh công cụ dọc có nền trắng, viền, góc bo card và các nút icon min-size (36×36). Công cụ đang chọn dùng sky100/sky600; radius của icon button chưa được cấu hình tường minh tại đó. Không dùng radius của shell toolbar làm radius của từng nút.

Studio top bar cao (54); bảng `StageContainer` giữ tỷ lệ (16:9), góc bo panel, có nội dung bảng/PDF và các overlay hiện có. Panel phải rộng (320), hiển thị phủ lên stage theo code. Các điều khiển soạn bài và lớp trực tiếp là hai nhóm riêng; biểu hiện thị giác không được làm lẫn trạng thái đó.

### Layout, motion and previews

Mốc hiện có: login chuyển layout tại (740), dashboard tại (800), sảnh tại (960); inspector studio dock khi đủ (1250). Đây là breakpoint riêng từng bề mặt; không phải thang responsive toàn app. Dashboard max-width (1100); sảnh max-width (1200). Shortcut đề thi đổi số cột dựa trên chiều rộng container (600/1000), không phải viewport.

Action card có thời lượng (180 ms), `Curves.easeOutCubic`, icon mũi tên dịch ngang (2); stage switch dùng (200 ms). Chưa xác minh một cơ chế reduced-motion toàn app. Không ghi fallback chưa triển khai thành tính năng đang có.

Sidecar gồm bản dịch HTML/CSS từ component Dart để xem trước độc lập. Nó không render widget Flutter; các focus/hover do Material quyết định được ghi nhãn là xấp xỉ preview, không trở thành token chuẩn. Các mẫu được dùng để tham khảo thị giác, không thay thế kiểm tra app thật.

**The The Observed State Rule.** Không suy ra hover, focus, disabled hoặc motion từ tên token; chỉ coi là xác nhận khi source cấu hình rõ hoặc có bằng chứng render.

## Do's and Don'ts

### Do

- Do giữ yêu cầu “supportive, clear, and trustworthy” trong PRODUCT.md; dùng tên HocLucStation cho tài liệu thiết kế.
- Do dùng token màu theo vai trò và phạm vi component; primary mặc định của MaterialApp là slate900, còn nút dạy học được style riêng bằng sky600.
- Do giữ nguyên bố cục hiện tại khi thực hiện kế hoạch thay diện mạo; thang AppSpacing hiện có không đồng nghĩa được phép dàn lại trang.
- Do giữ font Manrope cho UI, Literata cho dấu nhận diện hiện có và hệ màu riêng cho bảng/nét bút.
- Do kiểm tra contrast, clipping nhãn và trạng thái bàn phím bằng app render trước khi kết luận đạt chất lượng.

### Don't

- Don't thêm “visual or interaction choices that make teaching tasks harder to understand or interrupt classroom flow” — nguyên văn anti-reference trong PRODUCT.md; người dùng không cung cấp mẫu cần tránh có tên riêng.
- Don't biến gradient, thẻ nhấc khi hover, bóng rộng hoặc bo góc shell đăng nhập thành quy tắc cho component mới; đây là các đặc điểm kế thừa được ghi nhận.
- Don't đổi bố cục theo ảnh A/B/C, thêm sidebar/filmstrip hoặc thay điều hướng trong lượt thay diện mạo.
- Don't thêm minh họa giáo dục, biểu tượng lấp lánh hoặc lớp trang trí chỉ để tạo cảm giác giáo dục.
- Don't gọi preset dark, skyHover hoặc các trạng thái kế thừa Material là hành vi đã hoạt động/được đo khi chưa có bằng chứng.

