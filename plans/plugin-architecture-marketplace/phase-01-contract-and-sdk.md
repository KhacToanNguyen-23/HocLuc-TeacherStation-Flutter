# Phase 01: Contract & Plugin SDK Layer

**Parent Plan:** `plans/plugin-architecture-marketplace/plan.md`  
**Stories Covered:** Developer Story (P1), FR-01, FR-04  
**Risk Tier:** normal  

---

## 1. Goal
Thiết lập bộ hợp đồng giao tiếp chuẩn hóa giữa Webview và Flutter Host, đồng thời chuyển đổi plugin hiện tại `english_assistant` sang sử dụng SDK mới và nhận dynamic port.

---

## 2. Tasks & Detailed Implementation Steps

1. **Tạo thư viện SDK chuẩn `plugins/sdk/hocluc-plugin-sdk.js`**:
   - Cung cấp module JavaScript với các phương thức RPC:
     - `HocLuc.getContext()`: Lấy thông tin môi trường, phiên bản app.
     - `HocLuc.board.getSelectedText()`: Đọc text hoặc vùng đang chọn trên đề thi.
     - `HocLuc.board.insertAnnotation(annotation)`: Ghim LaTeX, nhãn dán, kết quả phân tích lên bảng.
     - `HocLuc.storage.get(key)` / `HocLuc.storage.set(key, value)`: Lưu trữ trạng thái cục bộ của plugin.
   - Cơ chế hoạt động: Đóng gói tin nhắn dạng JSON `{ id: string, action: string, payload: any }`, gửi qua `window.chrome.webview.postMessage` và chờ Promise phản hồi.

2. **Nâng cấp `plugins/english_assistant/manifest.json` theo Schema v2**:
   - Thêm khai báo schema, placement, permissions cụ thể (`board:insert_annotation`, `board:read_text`), cấu hình backend entry và health endpoint.

3. **Refactor `plugins/english_assistant/ui/app.js`**:
   - Nhúng `sdk.js` cục bộ vào `plugins/english_assistant/ui/sdk.js`.
   - Thay thế việc gọi trực tiếp các phương thức window/postMessage thủ công bằng lời gọi hàm thông qua `HocLuc` SDK.

4. **Cập nhật `plugins/english_assistant/engine/service.py`**:
   - Sử dụng thư viện `argparse` để tiếp nhận cờ `--port <port>` từ dòng lệnh.
   - Thêm endpoint `GET /health` trả về `{"status": "ok", "plugin": "com.hocluc.plugin.english"}` để Host kiểm tra trạng thái sẵn sàng.

---

## 3. Verification Criteria
- [ ] `plugins/english_assistant/ui/index.html` tải không bị lỗi console JavaScript.
- [ ] Khởi chạy thử nghiệm `python service.py --port 19999` độc lập -> Truy cập `http://127.0.0.1:19999/health` trả về mã 200 OK.
