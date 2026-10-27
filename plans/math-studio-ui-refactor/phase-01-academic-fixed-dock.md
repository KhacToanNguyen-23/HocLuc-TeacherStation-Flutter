# Phase 1: Thanh Dock Toán Học Cố Định & Chuẩn Hóa Học Thuật

## Goal
Tái thiết kế giao diện plugin `plugins/math_studio` thành Thanh Dock cố định tinh gọn với bảng màu sáng học thuật (Academic Light Palette), loại bỏ 100% emoji và câu từ rườm rà, sửa lỗi caret trong thanh nhập công thức và đổi tên chuẩn thương hiệu thành **Học Lực Math Studio**.

## Target Files
- `plugins/math_studio/manifest.json`
- `plugins/math_studio/ui/index.html`
- `plugins/math_studio/ui/style.css`
- `plugins/math_studio/ui/render/math_keyboard.js`

## Detailed Implementation Steps
1. **Chuẩn hóa manifest.json:**
   - Cập nhật name: `"Học Lực Math Studio"`
   - Version: `"2.1.0"`
   - Description: `"Studio Toán học Sư phạm: Đồ thị hàm số, Bảng biến thiên, Tích phân và Hình không gian 3D chuẩn SGK."`
   - Kích thước mặc định dock: `default_width: 620, default_height: 520` (hoặc compact dock bar).
2. **Thiết kế lại index.html:**
   - Xóa bỏ toàn bộ emoji (`📈`, `📊`, `📐`, `∮`, `📌`, `⬛`, `📝`).
   - Sử dụng các ký hiệu toán học vector thanh mảnh: $f(x)$, BBT, $3D$, $\int$.
   - Xóa các câu chú thích rườm rà ("Đang tạo...", "Chờ nhập...").
   - Đặt thanh công cụ dạng Fixed Dock trên đỉnh, bên dưới là vùng hiển thị đồ họa học thuật.
3. **Phong cách Academic Light trong style.css:**
   - Nền: `#FFFFFF` (Surface) và `#F8FAFC` (Canvas Stage).
   - Viền: `#E2E8F0` thanh mảnh 1px.
   - Chữ: `#0F172A` sắc nét, phông chữ Cambria Math / STIX Two Math.
   - Đồ thị: Đường nét mực xanh cobalt `#1E40AF` hoặc xanh Prussian `#0B3A82`, vạch chia tọa độ mảnh `#94A3B8`.
4. **Sửa lỗi thanh nhập liệu math_keyboard.js:**
   - Giữ nguyên focus và vị trí con trỏ (caret position) khi gõ phím.
   - Hỗ trợ gõ trực tiếp các biểu thức toán học tự do không bị giật lag.

## Acceptance Criteria
- [ ] Không còn bất kỳ ký tự emoji nào trong giao diện plugin và SVG xuất bản.
- [ ] Tên hiển thị chính thức là "Học Lực Math Studio".
- [ ] Gõ phím trong ô công thức mượt mà, không nhảy caret, đồ thị phản hồi tức thì.
- [ ] Giao diện sáng học thuật thanh lịch, không bị tối đen hay thô cứng.

