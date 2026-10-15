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

## 4. Đặc Tả Tệp `manifest.json`

```json
{
  "$schema": "https://hocluc.com/schemas/plugin.v2.json",
  "id": "com.hocluc.plugin.casio",
  "name": "Máy Tính Khoa Học Casio",
  "version": "1.0.0",
  "author": "Học Lực Math Team",
  "description": "Mô phỏng máy tính khoa học Casio FX-880BTG phục vụ giải toán trên bảng.",
  "main": "ui/index.html",
  "icon": "icon.png",
  "placement": "floating_window",
  "default_width": 380,
  "backend": null,
  "permissions": [
    "board:insert_annotation"
  ]
}
```

### Các trường quan trọng:
- `placement`: 
  - `"drawer_panel"`: Cột trượt cố định từ cạnh phải màn hình.
  - `"floating_window"`: Cửa sổ nổi kéo thả tự do trên nền bảng phấn.
- `permissions`:
  - `"board:insert_annotation"`: Quyền ghim kết quả/nhãn dán lên bảng.
  - `"board:read_text"`: Quyền đọc đoạn văn bản/vùng đề thi đang được giáo viên quét chọn.
- `backend`:
  - Đặt là `null` nếu plugin chỉ là HTML/JS thuần (ví dụ: máy tính, hình học phẳng Geogebra...).
  - Nếu có Python sidecar: Khai báo `{"type": "python", "entry": "engine/service.py", "health_endpoint": "/health"}`.

---

## 5. Hướng Dẫn Dùng Host Bridge SDK (`hocluc-plugin-sdk.js`)

Trong file `ui/app.js`, dev **chỉ được phép** giao tiếp với bảng phấn qua `HocLuc` SDK:

```javascript
import { HocLuc } from './sdk.js';

// 1. Lấy thông tin ngữ cảnh hiện tại
const context = await HocLuc.getContext();
console.log('Phiên bản app:', context.appVersion);

// 2. Đọc văn bản hoặc công thức đang được chọn trên đề thi
const selectedText = await HocLuc.board.getSelectedText();

// 3. Ghim nội dung/kết quả lên bảng phấn cho học sinh xem
await HocLuc.board.insertAnnotation({
  type: 'latex', // hoặc 'sticker', 'text'
  data: {
    latex: '\\int_{0}^{\\pi} \\sin(x) dx = 2',
    color: '#FACC15'
  }
});
```

---

## 6. Quy Trình Kiểm Thử Kiến Trúc (Bắt Buộc Trước Khi Push Code)

Trước khi commit code hoặc tạo Pull Request, chạy lệnh:
```powershell
flutter test test/architecture_test.dart
```

Nếu bài test báo **PASSED**, plugin của bạn đã đạt chuẩn kiến trúc và sẵn sàng đóng gói lên Marketplace!
