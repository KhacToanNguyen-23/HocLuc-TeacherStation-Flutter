# Phase 1: Vendor Assets & HTML/CSS Setup

## Goal
Tích hợp tài nguyên JSXGraph (offline) vào plugin `math_studio`, cập nhật `index.html` và tùy biến CSS.

## Requirements
1. `plugins/math_studio/ui/vendor/jsxgraph/jsxgraphcore.js` và `jsxgraph.css` có sẵn đầy đủ.
2. `index.html` tải `jsxgraph.css` và `jsxgraphcore.js`.
3. Bổ sung style cho JSXGraph box `#graphContainer` và `.jxgbox`:
   - Bo góc 8px, tràn viền sạch sẽ, loại bỏ viền xám mặc định của JSXGraph.
   - Định dạng typography cho nhãn toán học SGK (`.jxg-label`).
4. Khung xem trước hoạt động ổn định, không xung đột CSS với các thẻ điều khiển khác.

## Success Criteria
- File vendor tồn tại với dung lượng chính xác (> 900KB cho js, > 4KB cho css).
- `index.html` liên kết đúng đường dẫn tương đối `vendor/jsxgraph/jsxgraph.css` và `vendor/jsxgraph/jsxgraphcore.js`.

