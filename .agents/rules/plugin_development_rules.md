# Plugin Architecture & Development Rules (BẮT BUỘC CHO TẤT CẢ AGENT)

Khi phát triển mới, bảo trì hoặc refactor bất kỳ tính năng nào liên quan đến **Plugin** trong dự án Học Lực Teacher Station, AI Agent **BẮT BUỘC** phải tuân thủ các nguyên tắc bất biến (Hard Invariants) sau:

---

## 1. CẤM TUYỆT ĐỐI (Hard Prohibitions)
1. **KHÔNG ĐƯỢC PHÉP hardcode** bất kỳ định danh plugin nào (như `'english_assistant'`, `'com.hocluc.plugin.english'`, `'casio'`) vào trong thư mục mã nguồn Flutter Core (`frontend/lib/`).
2. **KHÔNG ĐƯỢC PHÉP import chéo** từ `frontend/lib/` vào thư mục `plugins/` hoặc ngược lại. Core và Plugin chỉ giao tiếp thông qua giao thức Interface trừu tượng và Host Bridge.
3. **KHÔNG ĐƯỢC PHÉP hardcode cổng mạng (port)** (ví dụ: cấm dùng cố định `18888`). Mọi Sidecar Engine (Python/Binary) bắt buộc phải nhận cổng động thông qua cờ dòng lệnh `--port <port>` hoặc biến môi trường `HOCLUC_PLUGIN_PORT` do Host cấp phát ngẫu nhiên.
4. **KHÔNG ĐƯỢC nạp toàn bộ raw bytes** của plugin vào bộ nhớ RAM (`filesMap` in-memory). Gói plugin tải về phải được giải nén ra ổ đĩa cục bộ `%LOCALAPPDATA%/HocLuc/plugins/<id>/v<version>/` và nạp vào RAM theo nhu cầu (On-Demand / Lazy Loading).
5. **KHÔNG ĐƯỢC gọi trực tiếp** `window.chrome.webview.postMessage` trong mã nguồn UI của plugin với định dạng tùy ý. Bắt buộc phải sử dụng thư viện chuẩn `hocluc-plugin-sdk.js`.

---

## 2. QUY CHUẨN CẤU TRÚC PLUGIN MỚI (Plugin Structure)
Mọi plugin mới bắt buộc phải nằm độc lập trong thư mục `plugins/<plugin_id>/` với cấu trúc chuẩn:
```text
plugins/<plugin_id>/
├── manifest.json         # (Bắt buộc) Khai báo metadata, permissions, runtime theo Schema v2
├── icon.png              # (Bắt buộc) Icon hiển thị tại Marketplace và thanh công cụ
├── ui/                   # Giao diện Webview của plugin
│   ├── index.html        # Entrypoint chính
│   ├── sdk.js            # Bản copy của hocluc-plugin-sdk.js
│   ├── app.js            # Logic giao diện của plugin
│   └── style.css
└── engine/               # (Tùy chọn) Mã nguồn Sidecar (Python/Binary) nếu có tính năng AI/Offline
    ├── service.py        # Entrypoint của sidecar (nhận param --port)
    └── requirements.txt
```

---

## 3. QUY CHUẨN MANIFEST.JSON (Schema v2.1)
Mọi tệp `manifest.json` phải tuân theo 1 trong 2 mẫu chuẩn sau:

### Mẫu A: Thiết bị vật lý nổi sát viền (`frameless: true` — Ví dụ: Máy tính Casio)
```json
{
  "$schema": "https://hocluc.edu.vn/schemas/plugin-manifest-v2.1.json",
  "id": "com.hocluc.plugin.<tên_plugin>",
  "name": "<Tên hiển thị tiếng Việt>",
  "version": "1.0.0",
  "description": "<Mô tả ngắn tính năng>",
  "author": "Học Lực Education",
  "icon": "icon.png",
  "ui": {
    "entry": "ui/index.html",
    "placement": "floating_window",
    "default_width": 336,
    "default_height": 624,
    "resizable": false,
    "frameless": true,
    "inject_sdk": true
  },
  "backend": null,
  "permissions": ["board:insert_annotation", "storage"]
}
```

### Mẫu B: Trợ giảng môn học kèm khay công cụ (`contributes.tools` — Ví dụ: Tiếng Anh)
```json
{
  "$schema": "https://hocluc.edu.vn/schemas/plugin-manifest-v2.1.json",
  "id": "com.hocluc.plugin.<tên_plugin>",
  "name": "<Tên hiển thị tiếng Việt>",
  "version": "1.0.0",
  "description": "<Mô tả ngắn tính năng>",
  "author": "Học Lực Education",
  "icon": "icon.png",
  "ui": {
    "entry": "ui/index.html",
    "placement": "bottom_drawer",
    "default_width": 440,
    "default_height": 520,
    "resizable": true,
    "inject_sdk": true
  },
  "contributes": {
    "tools": [
      {
        "id": "snip_tool",
        "label": "Khoanh vùng",
        "icon": "crop_free",
        "action": "snip_region",
        "target": "grammar",
        "tooltip": "Khoanh vùng nội dung trên bảng để phân tích"
      }
    ]
  },
  "backend": {
    "type": "python",
    "entry": "engine/service.py",
    "health_check": "/health"
  },
  "permissions": ["board:read_selection", "board:insert_annotation", "storage"]
}
```

---

## 4. QUY TRÌNH 3 CÔNG ĐOẠN: THÊM — SỬA — XÓA PLUGIN

### A. Thêm Plugin Mới (ADD):
1. Tạo thư mục `plugins/<plugin_id>/` độc lập với `manifest.json`, `icon.png`, `ui/index.html`.
2. Đóng gói ra file `.hlep`: `node scripts/package_plugin.mjs <plugin_id>`.
3. Kiểm tra tính toàn vẹn: `node scripts/validate_plugins.mjs`.
4. Xác minh CI Gate: `cd frontend && flutter test test/architecture_test.dart`.

### B. Chỉnh Sửa Plugin (EDIT):
1. Sửa code trong `plugins/<plugin_id>/`. CẤM sửa bất kỳ file nào trong `frontend/lib/`.
2. Tăng trường `version` trong `manifest.json` (SemVer `x.y.z`).
3. Đóng gói lại bắt buộc: `node scripts/package_plugin.mjs <plugin_id>`.
4. Kiểm tra độ tươi mtime: `node scripts/validate_plugins.mjs`.

### C. Xóa Plugin (DELETE):
1. Xóa thư mục nguồn `plugins/<plugin_id>/`.
2. Xóa đồng thời file nén `plugins/<plugin_id>.hlep` (Tránh lỗi Orphan Package).
3. Kiểm tra lại: `node scripts/validate_plugins.mjs`.

---

## 5. CHỐT CHẶN KIỂM THỬ BẮT BUỘC TRƯỚC KHI COMMIT & HOÀN THÀNH TASK
Trước khi kết thúc bất kỳ task nào liên quan đến plugin, Agent bắt buộc phải:
1. Đảm bảo Git Hook đã hoạt động: `node scripts/setup_hooks.mjs`.
2. Chạy Fast Validator:
   ```powershell
   node scripts/validate_plugins.mjs
   ```
   *(Hoặc dùng `node scripts/validate_plugins.mjs --fix` để tự động sửa các gói bị out-of-sync).*
3. Chạy Deep Architecture Test:
   ```powershell
   cd frontend
   flutter test test/architecture_test.dart
   ```
Nếu test không pass hoặc phát hiện vi phạm phân tầng kiến trúc, Agent không được phép tuyên bố hoàn thành task.
