# Phase 5: Kiểm chứng chạy thật

## Mục tiêu
Có bằng chứng chức năng chạy thật, tách bạch phần máy kiểm chứng và phần người dùng kiểm chứng.

## A. E2E tự động (Edge headless qua `puppeteer-core`, đặt tại `engine/tests/e2e/`)
Mock `window.chrome.webview` để bắt message RPC mà SDK gửi, trả response giả lập thành công.
1. Mở `ui/index.html` (qua máy chủ tĩnh cục bộ), chặn mọi request ngoài localhost → xác nhận offline.
2. Gõ lần lượt 8 hàm: kiểm dòng y' (ví dụ `2x^2-3x+1` → `4x-3`), các thẻ cập nhật, số element trên canvas > 0, không lỗi console.
3. Trang Đồ thị: mô phỏng kéo M tới x0=2 → độ dốc hiển thị 9; kéo y=m → số nghiệm khớp bảng chuẩn.
4. Trang BBT: số cột và dấu khớp mô hình chuẩn cho `x^3-3x`.
5. Trang Tích phân: n=4→50, số cột = n, S_n hội tụ; bật khối tròn xoay: V=8π; xoay → số nét đứt thay đổi.
6. Bấm Ghim ở 3 trang: mock nhận `board:insert_annotation` với `imageBase64` (PNG hợp lệ, kích thước ≥ 2x) hoặc `svgContent` không rỗng; bấm Đóng → nhận `window:close`.
7. Lưu ảnh chụp màn hình các trang vào `plans/math-studio-real-engine/evidence/`.
8. Đo thời gian cập nhật khi đổi hàm (≤ 100 ms) và FPS khi kéo (≥ 30).

## B. Người dùng kiểm tra trong app thật (agent không điều khiển được GUI Flutter)
Checklist 8 mục ngắn, người dùng đánh dấu: mở plugin từ Marketplace/sideload; nhập `x^3-3x`; kéo M; kéo y=m; chuyển tab BBT; Riemann kéo n; khối tròn xoay xoay chuột; Ghim → thẻ trên bảng đen có nội dung và co giãn/xoay được; tắt mạng mở lại.

## C. Báo cáo
`plans/math-studio-real-engine/verification-report.md` với 2 mục bắt buộc: "Đã chạy thật (có output/ảnh)" và "Chưa kiểm chứng (và lý do)". Không dùng chữ "đạt 100%" khi còn mục chưa kiểm chứng.

## Cập nhật `feature_list.json`
- `passing` chỉ khi test E2E/engine tương ứng đã chạy; phần cần người dùng xác nhận đặt `passing-unverified` cho tới khi có xác nhận.

