# Phase 0: Spike go/no-go — Excalidraw trong WebView2 thật

## Mục tiêu
Trả lời bằng thực nghiệm 4 câu hỏi trước khi viết engine/UI, để không lặp lại việc xây trên giả định:
1. Bundle Excalidraw (esbuild, IIFE) có chạy trong WebView2 qua `PluginWebServer` (cổng động, SDK auto-inject) không?
2. Chạy hoàn toàn offline (font chữ vẽ tay không tải CDN)?
3. Cách kéo điểm M và đường y=m khi đã ẩn toolbar: (a) edit mode + `locked` các element khác + ẩn UI, hay (b) `viewModeEnabled` + overlay bắt pointer + `updateScene`.
4. Kích thước bundle sau tối ưu và thời gian mở.

## File
- Tạo: `plugins/math_studio/package.json`, `plugins/math_studio/build.mjs`, `plugins/math_studio/src/spike/entry.jsx`
- Sửa: `.gitignore` (thêm `plugins/*/node_modules/`)
- Kết quả: ghi vào `plans/math-studio-real-engine/spike-result.md` (không chứa mã sản phẩm).

## Bước
1. `package.json` (private) với dep: `@excalidraw/excalidraw@0.18.1`, `react@19`, `react-dom@19`, `mathjs`, `nerdamer`; devDep: `esbuild`, `puppeteer-core`. Cài ngoài sandbox (cần mạng).
2. `build.mjs` dùng API esbuild (không dùng CLI — tránh lỗi quoting): `conditions:['production']`, `format:'iife'`, loader `.woff2/.woff/.ttf` = `file`, define `process.env.NODE_ENV` và `import.meta.env`, `metafile:true`; in bảng kích thước.
3. Spike entry: render `<Excalidraw>` với `UIOptions` ẩn công cụ, `zenModeEnabled`, thử CẢ HAI cách kéo (a) và (b) bằng 1 ellipse "M" + 1 line "y=m"; đọc vị trí qua `onChange` / `excalidrawAPI.getSceneElements()`.
4. Tìm cấu hình font offline: `window.EXCALIDRAW_ASSET_PATH` trỏ tới thư mục fonts local (nằm trong `ui/dist/`); xác nhận không có request ra ngoài (theo dõi network trong headless).
5. Nạp spike vào app thật: đóng gói tạm `.hlep` dev → "Nạp gói .hlep từ máy" (cách sideload trong guide) hoặc chạy qua Edge headless + mock `window.chrome.webview`. Nếu không chạy được app thật trong môi trường agent → ghi rõ "CHƯA kiểm chứng trong WebView2", yêu cầu người dùng chạy 1 checklist 3 bước.
6. Đo: kích thước JS/CSS/fonts; thời gian từ load đến `onMount`; thử tree-shake (`mathjs` import theo hàm `create({...})` thay vì full) và tách `lazy` các phần không dùng.

## Tiêu chí Go / No-Go
- GO: canvas Excalidraw hiển thị, kéo M và y=m cập nhật được vị trí đọc ra từ scene, font load từ local, không request ngoài.
- Ghi quyết định (a) hay (b) kèm lý do.
- NO-GO: dừng, báo người dùng, đề xuất dự phòng và chờ chấp thuận.

