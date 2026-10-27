# Phase 1: Plugin Scaffold & Dark UI Shell (Zero-Build ES Modules)

**Plan:** [plan.md](plan.md)  
**Spec Stories:** [P1] US-05 | **Requirements:** FR-09, FR-10, NFR-02, NFR-05

---

## 1. Mục Tiêu Phase 1
- Thiết lập cấu trúc thư mục chuẩn Schema v2.1 cho plugin độc lập `plugins/math_studio/`.
- Khai báo đầy đủ metadata trong `manifest.json` theo quy định của Teacher Station (chế độ `floating_window`, kích thước khởi đầu $460 \times 600$, `resizable: true`, `inject_sdk: true`, quyền `board:insert_annotation`).
- Tạo biểu tượng plugin `icon.png` (256x256 vector đồ họa hàm số / bảng phấn).
- Xây dựng giao diện Webview hiện đại Dark Chalkboard (`ui/index.html`, `ui/style.css`, `ui/app.js`) sử dụng bảng màu Catppuccin Mocha đồng bộ với Teacher Station.
- Hỗ trợ thanh chuyển Tab mượt mà:
  1. Hàm bậc ba ($y = ax^3 + bx^2 + cx + d$)
  2. Hàm trùng phương ($y = ax^4 + bx^2 + c$)
  3. Phân thức bậc nhất/bậc nhất ($y = \frac{ax+b}{cx+d}$)
  4. Phân thức bậc hai/bậc nhất ($y = \frac{ax^2+bx+c}{px+q}$)
  5. Tích phân & Diện tích hình phẳng ($\int_a^b |f(x)|dx$)
- Nút chuyển đổi nhanh giữa chế độ Cửa sổ nổi (Floating Window) và Thanh bên (Sidebar Drawer).
- Sao chép bộ SDK `ui/sdk.js` từ `frontend/assets/scripts/hocluc-plugin-sdk.js`.

---

## 2. Chi Tiết File Thay Đổi & Tạo Mới

### 2.1. `plugins/math_studio/manifest.json`
```json
{
  "$schema": "https://hocluc.com/schemas/plugin.v2.json",
  "id": "com.hocluc.plugin.math_studio",
  "name": "Math Studio (Giải Tích & BBT)",
  "version": "1.0.0",
  "author": "Học Lực Math Engineering Team",
  "description": "Bộ công cụ giải tích THPT: Tự động lập Bảng biến thiên chuẩn SGK, vẽ đồ thị 2D, tiệm cận và tính tích phân diện tích hình phẳng.",
  "category": "math",
  "main": "ui/index.html",
  "icon": "icon.png",
  "placement": "floating_window",
  "default_width": 460,
  "default_height": 620,
  "resizable": true,
  "frameless": false,
  "inject_sdk": true,
  "backend": null,
  "contributes": {
    "tools": [
      {
        "id": "open_math_studio",
        "label": "Toán Studio",
        "icon": "functions",
        "action": "toggle_tool"
      }
    ]
  },
  "permissions": [
    "board:insert_annotation"
  ]
}
```

### 2.2. `plugins/math_studio/ui/index.html`
- Header: Logo Học Lực Math Studio, badge trạng thái Host Bridge.
- Tabs Bar: 5 tab chọn dạng hàm số.
- Form Input: Các ô nhập hệ số $a, b, c, d$ hoặc phân số với placeholder rõ ràng, hỗ trợ phím Enter để tính tức thì.
- Action Bar:
  - Nút `[ Khảo Sát & Lập BBT ]`
  - Nút `[ Chèn BBT Vào Bảng ]`
  - Nút `[ Chèn Đồ Thị Vào Bảng ]`
- Preview Area:
  - Khung Bảng biến thiên (SVG container).
  - Khung Đồ thị Oxy (SVG container).
  - Khung kết quả tóm tắt (TXD, Đạo hàm, Cực trị, Tiệm cận, Tích phân).

### 2.3. `plugins/math_studio/ui/style.css`
- Dark chalkboard aesthetic: Background `#181825` (Catppuccin Mantle), Cards `#1e1e2e` (Catppuccin Base), Accent `#89b4fa` (Blue) / `#a6e3a1` (Green), Text `#cdd6f4`.
- Input fields dạng toán học (font monospace/serif toán học rõ ràng, hiển thị phân số trực quan).

---

## 3. Tiêu Chí Nghiệm Thu (Acceptance Criteria)
- [ ] File `plugins/math_studio/manifest.json` và `icon.png` hợp lệ.
- [ ] Chạy `node scripts/validate_plugins.mjs` nhận diện plugin `com.hocluc.plugin.math_studio` và không báo lỗi schema.
- [ ] Giao diện Webview mở lên hiển thị đúng 5 tab và responsive từ chiều rộng 360px đến 800px.
