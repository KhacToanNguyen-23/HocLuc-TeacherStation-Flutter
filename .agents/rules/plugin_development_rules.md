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

## 4. ĐÓNG GÓI `.hlep` & KIỂM THỬ KIẾN TRÚC BẮT BUỘC
Trước khi kết thúc bất kỳ task nào liên quan đến plugin, Agent bắt buộc phải:
1. Đóng gói lại file `.hlep`:
   ```powershell
   node scripts/package_plugin.mjs <tên_thư_mục_plugin>
   ```
2. Chạy lệnh kiểm thử kiến trúc (cũng là cổng chặn cứng trên GitHub Actions CI):
   ```powershell
   flutter test test/architecture_test.dart
   ```
Nếu test không pass hoặc phát hiện vi phạm phân tầng kiến trúc, Agent không được phép tuyên bố hoàn thành task.
