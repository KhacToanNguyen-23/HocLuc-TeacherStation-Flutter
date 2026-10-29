# Phase 2: Thanh lọc mã nguồn Plugin Math Studio & Thiết lập Excalidraw

## Mục tiêu
Dọn sạch toàn bộ thư mục `logic/` thừa, các file CAS và Exporter trùng lặp, thanh lọc regex hardcode trong `plugins/math_studio/`, thiết lập cấu trúc module sạch sẽ và tích hợp Excalidraw Engine vào giao diện web.

## File tác động
- Xóa thư mục: `plugins/math_studio/logic/` (`entry.js`, `main.js`)
- Xóa: `plugins/math_studio/ui/core/micro_cas.js` (trùng lặp với math_cas)
- Xóa: `plugins/math_studio/ui/render/export_helper.js` (trùng lặp với board_exporter)
- Sửa: `plugins/math_studio/manifest.json`:
  - Khôi phục `"runtime": "webview"` (hoặc bỏ field runtime vì mặc định là webview)
  - Xóa `"logic_entry"`
  - Giữ `"inject_sdk": true`
- Sửa/Cấu trúc lại thư mục `plugins/math_studio/ui/`:
  - `ui/index.html`: Khung sườn HTML 3 trang hiện đại, responsive.
  - `ui/style.css`: Hệ màu phấn bảng dạ quang (cyan, vàng chanh, hồng, trắng trên nền dark canvas).
  - `ui/vendor/`: Tích hợp thư viện Excalidraw / Rough.js canvas renderer tối ưu.

## Các bước triển khai
1. Xóa thư mục `plugins/math_studio/logic/`.
2. Dọn các file trùng lặp trong `ui/core/` và `ui/render/`.
3. Cập nhật `manifest.json`:
   ```json
   {
     "$schema": "https://hocluc.edu.vn/schemas/plugin-manifest-v2.1.json",
     "id": "com.hocluc.plugin.math_studio",
     "name": "Học Lực Math Studio",
     "version": "2.1.0",
     "author": "Học Lực Math Engineering Team",
     "description": "Studio Toán học Sư phạm: Đồ thị hàm số, Bảng biến thiên, Tích phân Riemann và Khối tròn xoay 3D.",
     "category": "math",
     "icon": "icon.png",
     "ui": {
       "entry": "ui/index.html",
       "placement": "modal",
       "movable": false,
       "default_width": 1080,
       "default_height": 640,
       "resizable": true,
       "frameless": true,
       "inject_sdk": true
     },
     "backend": null,
     "contributes": {
       "tools": [
         {
           "id": "open_math_studio",
           "label": "Đồ thị hàm số",
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
4. Kiểm tra hợp lệ manifest bằng `node scripts/validate_plugins.mjs`.

## Tiêu chí hoàn thành (Verification)
- `node scripts/validate_plugins.mjs` kiểm tra `math_studio` hợp lệ 100% Schema v2.1.
- Không còn file rác hoặc trùng lặp trong `plugins/math_studio/`.

