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

## 4. Đặc Tả Tệp `manifest.json` (Schema v2.1 — 2 Mẫu Copy-Paste Chuẩn)

### Mẫu 1: Thiết Bị Vật Lý Sát Viền (`frameless: true` — Ví dụ: Máy tính Casio, Thước đo độ)
Hiển thị **chỉ đúng thân thiết bị vật lý** nổi trên bảng đen (không có khung viền trắng/header/footer thừa của Host, kéo thả trực tiếp trên viền trên của máy và nút `×` gọn nhẹ):

```json
{
  "$schema": "https://hocluc.edu.vn/schemas/plugin-manifest-v2.1.json",
  "id": "com.hocluc.plugin.casio",
  "name": "Máy tính Casio fx-580VN X",
  "version": "1.1.1",
  "author": "Học Lực Education",
  "category": "math",
  "description": "Máy tính khoa học Casio fx-580VN X sát viền thật trên bảng đen.",
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

### Mẫu 2: Trợ Giảng Môn Học Kèm Khay Công Cụ (`contributes.tools` — Ví dụ: Tiếng Anh)
Hiển thị ngăn kéo gắn bài giảng kèm thanh công cụ nổi (`SubjectToolPalette`) tự động sinh từ `contributes.tools`:

```json
{
  "$schema": "https://hocluc.edu.vn/schemas/plugin-manifest-v2.1.json",
  "id": "com.hocluc.plugin.english",
  "name": "Trợ giảng Tiếng Anh",
  "version": "2.1.0",
  "author": "Học Lực Education",
  "category": "english",
  "description": "Phân tích ngữ pháp S-V-O-A và đọc hiểu ĐGNL trên bảng phấn.",
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
        "id": "snip_grammar",
        "label": "Khoanh vùng",
        "icon": "crop_free",
        "action": "snip_region",
        "target": "grammar",
        "tooltip": "Khoanh vùng câu tiếng Anh trên bảng để bóc tách S-V-O-A"
      },
      {
        "id": "quick_sentence",
        "label": "Nhập câu",
        "icon": "edit_note",
        "action": "quick_input",
        "widgetKey": "quick_sentence_button",
        "tooltip": "Nhập / Chọn câu bóc tách S-V-O-A"
      }
    ]
  },
  "backend": {
    "type": "python",
    "entry": "engine/service.py",
    "health_endpoint": "/health"
  },
  "permissions": ["board:read_selection", "board:insert_annotation", "storage"]
}
```

### Các trường quan trọng:
- `ui.placement`:
  - `"bottom_drawer"` / `"drawer_panel"`: Ngăn kéo gắn vào bài giảng, đi kèm thanh công cụ nổi (`SubjectToolPalette`) hiển thị các nút khai báo trong `contributes.tools`.
  - `"floating_window"`: Cửa sổ nổi độc lập kéo thả tự do trên nền bảng phấn (có thể mở song song cùng lúc với một plugin ngăn kéo).
- `ui.frameless`:
  - Đặt `true` cho thiết bị mô phỏng vật lý (như Casio fx-580VN X) để ẩn toàn bộ header/footer/khung nền của Host, chỉ hiển thị đúng thân thiết bị với dải kéo thả trong suốt ở viền trên (`top: 0..28px`).
- `ui.inject_sdk`:
  - Đặt `true` khi bạn nhúng một dự án Open-Source có sẵn (HTML/JS/WASM như GeoGebra, Desmos, JSMol, Casio Simulator). `PluginWebServer` sẽ tự động tiêm `<script src="/__hocluc_sdk__/hocluc-plugin-sdk.js"></script>` vào trang HTML mà không cần sửa mã nguồn gốc của dự án Open-Source.
- `ui.transparent_background`:
  - Mặc định là `false`. Đặt `true` chỉ khi giao diện plugin có vùng kính đăng ký qua SDK và trang tự giữ nền opaque làm fallback. Trên Windows, Host đặt nền WebView2 trong suốt trước navigation; nếu runtime từ chối, plugin tiếp tục với nền opaque. Khi vùng kính hiện, plugin có thể dùng `html[data-hocluc-transparent-background='true']` để mở nền trong suốt cục bộ.
- `contributes.tools`:
  - Khai báo các công cụ gắn vào thanh `SubjectToolPalette` trên bảng phấn theo chuẩn `Contribution Points` của VS Code (`action`: `"snip_region"`, `"toggle_tool"`, `"quick_input"`).
- Tool fields `pdf_tap_mode` and `captures_board_input` reserve PDF tap or board input gestures for the declared contributed tool. A plugin may activate a declared toggle tool with `window.HocLuc.board.setTool(target, enabled)` and must request `board:control_tools` permission.
- A `toggle_tool` may declare `"text_selection_mode": true` to let teachers drag-select native PDF text while it is active. Request `board:read_text` and listen with `window.HocLuc.onHostEvent('board:text_selected', ({text, target}) => { ... })`. Events go only to the plugin owning the active target, respect the document's copy permission, normalize whitespace, and ignore empty or over-500-character selections. This mode cannot be combined with `pdf_tap_mode` or `captures_board_input`. Scanned/image-only PDFs require OCR via a separate workflow.
- A `snip_region` contribution may declare `"snip_text_only": true` to receive extracted text without running the host's legacy language analysis. It requires `board:read_text`; text is delivered via the existing `onSnippetCaptured(text, target)` callback. Saved legacy analysis overlays remain intact but are hidden while a plugin with this raw-text capability is active.
- `backend`:
  - Optional `development_entry` can point to a sidecar's Dart source entry. In Flutter debug, the host runs that source through the Dart SDK; release continues to use `entry`. This avoids rebuilding the executable or repackaging `.hlep` for each engine edit during development.
  - Đặt là `null` nếu plugin chỉ là HTML/JS/WASM thuần.
  - Nếu có Python sidecar: Khai báo `{"type": "python", "entry": "engine/service.py", "health_endpoint": "/health"}`. Sidecar nhận cổng Host cấp qua `--port` hoặc `HOCLUC_PLUGIN_PORT`.

---

## 5. Hướng Dẫn Dùng Host Bridge SDK (`hocluc-plugin-sdk.js`)

Trong file `ui/app.js` (hoặc bất kỳ script nào khi bật `inject_sdk: true`), dev giao tiếp với bảng phấn qua `window.HocLuc`:

```javascript
// 1. Lấy thông tin ngữ cảnh hiện tại (kèm sidecarUrl nếu có Python Engine)
const context = await window.HocLuc.getContext();

// 2. Activate a tool declared in manifest.json (requires board:control_tools)
await window.HocLuc.board.setTool('declared_tool_target', true);

// 3. Add a generic board annotation (requires board:insert_annotation)
await window.HocLuc.board.insertAnnotation({
  type: 'lesson_note',
  data: { text: 'The student reads a book.' }
});

// 4. Receive generic PDF text/geometry events and publish plugin-produced regions.
window.HocLuc.onHostEvent('board:pdf_text_fragments', async (page) => {
  const regions = classifyPage(page); // plugin-owned implementation
  await window.HocLuc.board.publishPdfRegions(
    page.page_number,
    page.document_generation,
    page.page_size,
    regions,
  );
});
```

PDF tools must declare `board:read_text` and `board:publish_pdf_regions`; the Host only accepts region results from the currently active declared PDF tool and validates every region against the page bounds.

The Host publishes `board:tool_state` with `active_tool` when the toolbar changes,
and `board:pdf_tap` with `page_point`, `page_number`, and `document_generation`.
Plugins perform their own hit testing and generate annotation geometry. To toggle
a grouped closed path, request `board:annotate_pdf` and call:

```javascript
await window.HocLuc.board.togglePdfAnnotation(
  page.page_number, page.document_generation, page.page_size,
  region, affectedPages,
  { stroke: { points: [[0.1, 0.2], [0.3, 0.2], [0.2, 0.4]],
              color: 0xff008800, width: 3 }, persist: true },
);
```

Points are normalized page coordinates in `[0, 1]`, with 3–512 points per path;
color is an unsigned ARGB integer and width is in logical pixels (maximum 64).
The Host never generates a plugin's shape. It namespaces groups by plugin ID,
replaces the prior item in a group across affected pages, and supports persistence,
session-only overrides (`persist: false`), serialization, and undo/redo. Requests
for a stale PDF generation, inactive tool, or invalid geometry are rejected.

If incremental analysis merges provisional groups, call
`board.rekeyPdfAnnotationGroup(documentGeneration, fromId, toId, affectedPages)`
before publishing the new region IDs. This operation is scoped to the requesting
plugin. The Host merges persisted paths, session overrides, and undo/redo
timelines without adding a user undo step. Serialize analysis and tap handling
inside the plugin so taps cannot race a group migration.

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

## 7. Quy Trình Kiểm Thử Kiến Trúc & Git Pre-Commit Hook

Hệ thống sử dụng cơ chế bảo vệ 2 lớp để đảm bảo 100% plugin không bị lỗi thời hay vi phạm kiến trúc:

### Bước 1: Kích hoạt Git Hook (Chỉ cần chạy 1 lần sau khi clone repo)
```powershell
node scripts/setup_hooks.mjs
```
*(Nếu mở repo bằng VS Code, hook sẽ được kích hoạt hoàn toàn tự động trong nền).*

### Bước 2: Kiểm tra nhanh trước khi commit (Fast-Path Validator < 150ms)
```powershell
node scripts/validate_plugins.mjs
```
*(Nếu phát hiện gói `.hlep` bị out-of-sync do bạn sửa file code mà chưa đóng gói lại, có thể dùng `node scripts/validate_plugins.mjs --fix` để tự động đóng gói).*

### Bước 3: Chạy bài kiểm thử kiến trúc sâu (Deep-Path Gate CI)
```powershell
cd frontend
flutter test test/architecture_test.dart
```

---

## 8. Hướng Dẫn Cấu Hình Branch Protection Khóa Nhánh GitHub

Để đảm bảo không ai (kể cả Admin) có thể merge code vi phạm vào nhánh `main` hoặc `develop`:

1. Truy cập repo trên GitHub: **Settings** $\rightarrow$ **Branches** $\rightarrow$ **Branch protection rules**.
2. Chọn nhánh cần bảo vệ (`main` hoặc `develop`).
3. Tích chọn các mục sau:
   - ✅ **Require a pull request before merging**
   - ✅ **Require status checks to pass before merging**
   - Trong danh sách status checks, tìm và chọn: **`Flutter Lint & Tests`** (chính là job chạy `validate_plugins.mjs` và `architecture_test.dart`).
   - ✅ **Require branches to be up to date before merging**
   - ✅ **Do not allow bypassing the above settings** (Áp dụng cho cả Repository Administrators).

