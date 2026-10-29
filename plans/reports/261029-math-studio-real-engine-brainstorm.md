# Brainstorm: Math Studio — dùng thật Excalidraw + thư viện toán mở (sửa lại bản "UI tĩnh")

**Date:** 2026-10-29

## Vì sao brainstorm lại
Bản cook trước chỉ ra UI tĩnh, chức năng không dùng được. Nguyên nhân đã xác minh:
- Chỉ nhúng `rough.js` (27KB), KHÔNG có Excalidraw (editor/canvas/export).
- Không dùng thuật toán/engine nào của congcutoanhoc; `math_engine.js` là code tự viết với bảng regex hardcode cho `y'` và nguyên hàm (ảnh người dùng: f = 2x²-3x+1 nhưng y' vẫn 3x²-3; canvas không vẽ đường cong).
- Các báo cáo "đạt 100%" chỉ dựa trên architecture_test / validate_plugins / dart analyze (kiểm tra cấu trúc), chưa ai chạy UI.
- Tàn dư chưa dọn: `ui/board/graph_board.js`, `ui/core/{math_cas,store,geometry_parser,integral_solver,rational}.js`, `ui/export/board_exporter.js`, `ui/render/{bbt_generator,math_keyboard}.js`, `ui/vendor/jsxgraph/` (~1MB) — không được index.html mới dùng.

## Kết quả kiểm tra thực tế (đã chạy, không phải suy đoán)

### congcutoanhoc.com
- 271 công cụ: 128 trang tự viết, 96 link GeoGebra, 47 link ngoài.
- Công cụ liên quan (tiếp tuyến, diện tích hình phẳng + Riemann): **tính toán nằm ở API PHP phía server** (`api/calctieptuyen.php`, `api/calcdientichhinhphang.php`); trình duyệt chỉ nhận kết quả (`x, y, rectX, rectH, approxArea, integral`) rồi vẽ bằng Plotly. => Không có mã thuật toán để lấy.
- `tiemcan.php`, `ksvdt`: dùng applet GeoGebra + lệnh CAS. `dothidaoham.php`: math.js + Chart.js.
- Không có giấy phép/bản quyền ghi trên trang. Người dùng xác nhận không xin được phép.
- Kết luận: chỉ dùng "ý tưởng/hành vi" (ví dụ thanh trượt số hình chữ nhật Riemann, kéo điểm M cho tiếp tuyến) làm tham chiếu thiết kế; tự cài đặt bằng thư viện mở. KHÔNG sao chép mã, giao diện, văn bản, tài nguyên của họ; KHÔNG gọi API của họ.

### Thư viện mở (giấy phép lấy từ npm registry)
| Thư viện | Giấy phép | Dùng cho |
|---|---|---|
| @excalidraw/excalidraw 0.18.1 | MIT | canvas/zoom/pan/nét vẽ tay/xuất PNG-SVG |
| react, react-dom 19 | MIT | peer dependency của Excalidraw |
| mathjs 15.2.0 | Apache-2.0 | phân tích biểu thức, đạo hàm symbolic, simplify |
| nerdamer 2.0.0 | Apache-2.0 | nguyên hàm (cần kiểm tra độ phủ hàm) |
| esbuild 0.28.2 | MIT | bundle offline |

### Thử bundle Excalidraw offline (scratch, đã chạy thành công)
- esbuild bundle Excalidraw + React + mathjs: `entry.js` ≈ 8.98 MB (minified, chưa tách/tree-shake), `entry.css` 141 KB, 4 file font woff2 (80 KB).
- Phải bật `conditions: ['production']` để resolve `index.css`.
- Chưa đo: kích thước sau nén .hlep; font chữ vẽ tay (Excalifont) cần copy local để offline thật; hành vi trong WebView2.

## Ideas Explored
1. **Dùng thư viện mở tương đương (math.js + công thức chuẩn) + Excalidraw bundle offline** — được chọn.
2. Gọi API PHP của congcutoanhoc — loại (cần internet, không có phép, dễ hỏng).
3. Nhúng GeoGebra applet + CAS — loại tạm (nặng, giấy phép GeoGebra hạn chế thương mại, chưa xét).
4. Tiếp tục tự viết engine regex — loại (đã chứng minh sai).

## User's Direction
- "Lấy thuật toán của congcutoanhoc và render UI/UX từ Excalidraw" → vì không lấy được/không xin được phép: tự build từ thư viện mã nguồn mở dựa trên ý tưởng đó, UI đồ thị dùng Excalidraw.
- Chỉ dùng canvas Excalidraw, ẩn toàn bộ thanh công cụ vẽ.
- Giữ nguyên chốt cũ: 3 trang (Đồ thị & Khảo sát; Bảng biến thiên; Tích phân & Tròn xoay), nhập hàm tự do, kéo M/y=m, Riemann n∈[4,50], khối tròn xoay nét liền/đứt xoay đa góc, ghim bảng đen 8 điểm neo.

## Open Questions (plan phải giải)
1. Cách làm M và đường y=m kéo được khi đã ẩn toolbar: (a) chế độ edit + khóa mọi element trừ M/handle + ẩn UI; (b) viewMode + lớp overlay bắt pointer rồi `updateScene`. Cần spike.
2. Nguyên hàm tự động: hàm không có nguyên hàm sơ cấp thì hiển thị gì (đề xuất: báo "không có biểu thức sơ cấp" + tích phân số).
3. Cách kiểm thử chức năng tự động trong WebView (engine chạy được bằng node; phần UI cần smoke test thật).
4. Giảm kích thước bundle (ESM split, tree-shake mathjs, bỏ locale/mermaid nếu có).

## Risks
1. Excalidraw nặng (~9MB JS) và có thể chậm khi sinh nhiều element — đường cong dùng một element `line` nhiều điểm, không tạo hàng nghìn element.
2. Khối tròn xoay 3D không có trong Excalidraw (2D) — phải tự chiếu 3D→2D rồi sinh element nét liền/nét đứt; xoay = sinh lại scene.
3. Báo cáo hoàn thành lần trước sai — lần này tiêu chí hoàn thành bắt buộc có kiểm thử chức năng chạy thật, không chỉ cổng kiến trúc.

