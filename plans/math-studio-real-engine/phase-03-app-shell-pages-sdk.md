# Phase 3: App shell, 3 trang, tương tác, SDK

## Mục tiêu
Ghép engine + stage + Excalidraw thành 3 trang đúng wireframe đã chốt; bảng thông số là UI tự viết; Ghim và Đóng dùng SDK thật.

## File
- `ui/index.html`, `ui/style.css`: header (3 tab, nút Ghim, Đóng), cột trái (bảng thông số), cột phải (mount Excalidraw). Ô nhập f(x) và dòng y' thanh mảnh. KHÔNG có preset (đã bỏ theo yêu cầu).
- `src/app/main.jsx`: mount Excalidraw (cấu hình theo quyết định Phase 0), state trung tâm, debounce nhập ≤ 120 ms.
- `src/app/pages/graph.js`: thẻ Đơn điệu & Cực trị, Tiệm cận, Nguyên hàm, Tiếp tuyến tại M(x0), Tương giao y=m; đồng bộ 2 chiều thanh trượt ↔ kéo trên canvas.
- `src/app/pages/bbt.js`: bảng biến thiên toàn màn hình, xuất SVG từ `engine/bbt.js`.
- `src/app/pages/integral.js`: a, b, thanh trượt n∈[4,50], S_n so với tích phân chính xác, bật/tắt khối tròn xoay, góc quay, V; kéo chuột trên canvas để xoay (đổi rotX/rotY).
- `src/app/bridge.js`: bọc SDK: `HocLuc.board.insertAnnotation({type, data:{title, rawText, imageBase64|svgContent, aspectRatio, metadata}})`, `HocLuc.close()`. Không gọi `chrome.webview.postMessage` trực tiếp. `type` lấy từ `HocLuc.getContext()`/manifest, không hardcode chuỗi ID trong host; trong plugin được phép dùng ID của chính nó.
- Xuất ảnh: Excalidraw `exportToBlob` (PNG, scale 2, nền phù hợp bảng đen) cho đồ thị/tích phân/3D; `exportToSvg` hoặc SVG từ `bbt.js` cho BBT.
- Lỗi nhập: hiển thị thông báo trong thẻ, không để UI chết; bắt lỗi `insertAnnotation` (timeout 8s) và hiện trạng thái cho người dùng.

## Hành vi bắt buộc (khớp spec)
- Đổi hàm → y', các thẻ, canvas cập nhật ≤ 100 ms (đo bằng performance.now trong e2e).
- Kéo M: độ dốc hiển thị = f'(x0) (sai số < 1e-3); kéo y=m: số nghiệm khớp engine.
- Ghim ở cả 3 trang tạo annotation có `imageBase64` hoặc `svgContent` KHÔNG rỗng.
- Offline: không có request mạng nào khi mở trang.

## Tests / kiểm chứng
- Smoke e2e mức phase (chi tiết ở Phase 5): mở trang bằng Edge headless + mock `window.chrome.webview`, gõ hàm, kiểm DOM và số element canvas.
- Review thủ công mã: không còn tham chiếu `window.HocLuc.postMessage`.

## Tiêu chí hoàn thành
Build thành công (`npm run build`), trang mở trong Edge headless, 3 tab chuyển được, Ghim gọi đúng `board:insert_annotation` (bắt được trong mock) với payload hợp lệ.

