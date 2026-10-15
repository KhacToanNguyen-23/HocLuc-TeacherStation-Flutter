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

## 3. QUY CHUẨN MANIFEST.JSON (Schema v2)
Mọi tệp `manifest.json` phải chứa đầy đủ các trường sau:
```json
{
  "id": "com.hocluc.plugin.<tên_plugin>",
  "name": "<Tên hiển thị tiếng Việt>",
  "version": "1.0.0",
  "author": "Học Lực Studio",
  "description": "<Mô tả ngắn tính năng>",
  "main": "ui/index.html",
  "icon": "icon.png",
  "placement": "drawer_panel",
  "default_width": 420,
  "backend": {
    "type": "python",
    "entry": "engine/service.py",
    "health_endpoint": "/health"
  },
  "permissions": [
    "board:insert_annotation",
    "board:read_text"
  ]
}
```
*(Nếu plugin không có backend, đặt `"backend": null` hoặc bỏ qua khối này).*

---

## 4. QUY CHUẨN GIAO TIẾP VỚI BẢNG PHẤN (Host Bridge SDK)
Giao diện JavaScript của plugin chỉ được phép tương tác với ứng dụng thông qua SDK chuẩn:
```javascript
import { HocLuc } from './sdk.js';

// Đọc văn bản đang chọn trên bảng/tài liệu:
const text = await HocLuc.board.getSelectedText();

// Chèn ghi chú / nhãn dán lên bảng vẽ:
await HocLuc.board.insertAnnotation({
  type: 'sticker',
  data: { text: 'Nội dung phân tích', color: '#4ADE80' }
});
```

---

## 5. THỰC HIỆN KIỂM THỬ TRƯỚC KHI BÁO HOÀN THÀNH
Trước khi kết thúc task liên quan đến plugin, Agent bắt buộc phải chạy lệnh kiểm thử kiến trúc:
```powershell
flutter test test/architecture_test.dart
```
Nếu test không pass hoặc phát hiện vi phạm phân tầng kiến trúc, Agent không được phép tuyên bố hoàn thành task.
