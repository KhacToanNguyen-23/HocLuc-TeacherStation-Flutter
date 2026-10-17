# Hướng Dẫn Phát Triển Plugin & Quy Chuẩn Cho Lập Trình Viên (Developer Guide)

> **Dành cho:** Tất cả lập trình viên và AI Agent tham gia xây dựng tiện ích mở rộng (Plugin/Extension) cho hệ thống **Học Lực Teacher Station**.

---

## 1. Cơ Chế Tự Động Ràng Buộc AI Agent
Trong dự án này, hệ thống đã cài đặt tệp quy chuẩn tại:
👉 [`.agents/rules/plugin_development_rules.md`](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/.agents/rules/plugin_development_rules.md)

Khi bạn sử dụng **Antigravity IDE**, Agent sẽ **tự động nạp quy chuẩn này vào mọi phiên làm việc**. Bạn không cần phải cấu hình thêm bất kỳ điều gì.

Tuy nhiên, khi bắt đầu một prompt giao việc cho Agent để tạo mới hoặc bảo trì plugin, **khuyến nghị bạn tag kèm file tài liệu này vào câu lệnh prompt** để Agent tập trung tối đa ngữ cảnh:

```text
@docs/architecture/plugin-development-guide.md
Hãy tạo plugin mới [Tên Plugin] (ví dụ: Casio FX-880 / Trợ giảng Môn Hóa) 
tuân thủ tuyệt đối quy chuẩn kiến trúc trong tài liệu đính kèm.
```

---

## 2. Triết Lý Kiến Trúc: "Clean Microkernel + On-Demand Cache"

1. **Khách hàng (Giáo viên)**:
   - Chỉ cần cài ứng dụng Học Lực Desktop là chạy được ngay.
   - Khi cần dùng môn nào, mở Kho Plugin (Marketplace) trên thanh công cụ và bấm **"Tải về" (1-click)**.
   - Khi mở plugin, hệ thống mới nạp lên RAM. Khi đóng lại, toàn bộ RAM và tiến trình phụ được giải phóng hoàn toàn.

2. **Lập trình viên (Developer)**:
   - Mã nguồn của Plugin phải **hoàn toàn độc lập** trong thư mục `plugins/<plugin_id>/`.
   - **Tuyệt đối KHÔNG ĐƯỢC CHẠM VÀO `frontend/lib/`**: Không thêm logic `if (plugin == '...')`, không hardcode tên plugin, không hardcode cổng mạng (port).
   - Mọi giao tiếp với bảng vẽ phải thông qua file SDK chuẩn `hocluc-plugin-sdk.js`.

---

## 3. Khung Thư Mục Của Một Plugin Chuẩn (Template)

Mỗi plugin phải được tổ chức theo cấu trúc sau:
```text
plugins/
└── <plugin_id>/                  # Ví dụ: math_casio hoặc chemistry_lab
    ├── manifest.json             # Khai báo cấu hình bắt buộc
    ├── icon.png                  # Icon vuông (khuyến nghị 64x64 hoặc 128x128 png)
    ├── ui/                       # Giao diện chạy trong Webview (HTML/CSS/JS)
    │   ├── index.html            # Trang hiển thị chính
    │   ├── sdk.js                # Bản sao của thư viện hocluc-plugin-sdk.js
    │   ├── app.js                # Mã JavaScript xử lý UI của bạn
    │   └── style.css             # Giao diện thiết kế (ưu tiên dark mode phù hợp bảng)
    └── engine/                   # (Tùy chọn) Chỉ cần nếu có AI Engine cục bộ
        ├── service.py            # Khởi chạy API (nhận cờ --port động)
        └── requirements.txt
```

---

## 4. Đặc Tả Tệp `manifest.json` (Schema v2.1 — Chuẩn VS Code / Chrome Extension)

```json
{
  "$schema": "https://hocluc.com/schemas/plugin.v2.1.json",
  "id": "org.open.scientific_calc",
  "name": "Máy Tính Khoa Học",
  "version": "1.0.0",
  "author": "Học Lực Math Team",
  "category": "math",
  "description": "Mô phỏng máy tính khoa học phục vụ giải toán trên bảng.",
  "icon": "icon.png",
  "ui": {
    "entry": "ui/index.html",
    "placement": "floating_window",
    "default_width": 350,
    "default_height": 620,
    "resizable": false,
    "inject_sdk": true
  },
  "contributes": {
    "tools": [
      {
        "id": "snip_formula",
        "label": "Quét công thức",
        "icon": "crop_free",
        "action": "snip_region",
        "tooltip": "Khoanh vùng công thức trên bảng để đưa vào plugin"
      }
    ]
  },
  "backend": null,
  "permissions": [
    "board:insert_annotation"
  ]
}
```

### Các trường quan trọng:
- `ui.placement` (hoặc `placement`):
  - `"drawer_panel"`: Ngăn kéo gắn sâu vào bài giảng ở cạnh phải màn hình, đi kèm thanh công cụ nổi (`SubjectToolPalette`) hiển thị các nút khai báo trong `contributes.tools`.
  - `"floating_window"`: Cửa sổ nổi độc lập kéo thả tự do trên nền bảng phấn (có thể mở song song cùng lúc với một plugin `drawer_panel`).
- `ui.inject_sdk`:
  - Đặt `true` khi bạn nhúng một dự án Open-Source có sẵn (HTML/JS/WASM như GeoGebra, Desmos, JSMol, Casio Simulator). `PluginWebServer` sẽ tự động tiêm `<script src="/__hocluc_sdk__/hocluc-plugin-sdk.js"></script>` vào trang HTML mà không cần sửa mã nguồn gốc của dự án Open-Source.
- `contributes.tools`:
  - Khai báo các công cụ gắn vào thanh `SubjectToolPalette` trên bảng phấn theo chuẩn `Contribution Points` của VS Code (`action`: `"snip_region"`, `"board_annotation_mode"`, `"quick_text_input"`).
- `backend`:
  - Đặt là `null` nếu plugin chỉ là HTML/JS/WASM thuần.
  - Nếu có Python sidecar: Khai báo `{"type": "python", "entry": "engine/service.py", "health_check": "/health"}`.

---

## 5. Hướng Dẫn Dùng Host Bridge SDK (`hocluc-plugin-sdk.js`)

Trong file `ui/app.js` (hoặc bất kỳ script nào khi bật `inject_sdk: true`), dev giao tiếp với bảng phấn qua `window.HocLuc`:

```javascript
// 1. Lấy thông tin ngữ cảnh hiện tại (kèm sidecarUrl nếu có Python Engine)
const context = await window.HocLuc.getContext();

// 2. Ghim nội dung/thẻ kiến thức lên bảng phấn cho học sinh xem
await window.HocLuc.pinSticker({
  type: 'grammar_analysis',
  data: {
    sentence: 'The student reads a book.',
    tokens: [
      { text: 'The student', role: 'S' },
      { text: 'reads', role: 'V' },
      { text: 'a book', role: 'O' }
    ]
  }
});
```

---

## 6. Đóng Gói `.hlep` & Phát Hành Lên Backend Marketplace

1. **Đóng gói và kiểm tra Schema v2.1:**
   ```powershell
   node scripts/package_plugin.mjs <ten_thu_muc_plugin>
   ```
   Lệnh này kiểm tra tính hợp lệ của `manifest.json`, nén toàn bộ thư mục thành `plugins/<ten_thu_muc_plugin>.hlep` và in mã băm `SHA-256`.
2. **Thử nghiệm nhanh (Dev Sideload):**
   Mở bảng **Hoạt động & Tiện ích** trong Teacher Station $\rightarrow$ bấm biểu tượng **Nạp gói `.hlep` từ máy** trên thanh tiêu đề để cài trực tiếp.
3. **Phát hành lên Backend Marketplace:**
   Đặt file `.hlep` vào thư mục `plugins/` của Backend hoặc gọi `POST /api/marketplace/plugins/publish` (multipart `file`). Giáo viên bấm nút **Đồng bộ từ Marketplace** sẽ thấy plugin kèm icon, phiên bản và tải về trong 1 chạm.

---

## 7. Quy Trình Kiểm Thử Kiến Trúc (Bắt Buộc Trước Khi Push Code)

Trước khi commit code hoặc tạo Pull Request, chạy lệnh:
```powershell
flutter test test/architecture_test.dart
```

Nếu bài test báo **PASSED**, plugin của bạn đã đạt chuẩn kiến trúc và sẵn sàng đóng gói lên Marketplace!

