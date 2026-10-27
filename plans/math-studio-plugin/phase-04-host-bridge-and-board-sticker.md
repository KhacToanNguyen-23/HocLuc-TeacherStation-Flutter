# Phase 4: Host Bridge & Board Sticker Integration (Zero Hardcoded Names)

**Plan:** [plan.md](plan.md)  
**Spec Stories:** [P1] US-04 | **Requirements:** FR-07, FR-08, NFR-04

---

## 1. Mục Tiêu Phase 4
- Kết nối Plugin Webview với Host Studio Board qua `hocluc-plugin-sdk.js`:
  - `ui/render/export_helper.js`: Cung cấp hàm chuyển đổi SVG DOM sang chuỗi XML và Base64 Data URL.
  - Gắn sự kiện cho các nút hành động:
    - `[ Chèn Bảng Biến Thiên ]`: Gửi RPC `board:insert_annotation` với SVG bảng biến thiên.
    - `[ Chèn Đồ Thị 2D ]`: Gửi RPC `board:insert_annotation` với SVG đồ thị và miền tích phân.
  - Payload gửi lên Host:
    ```json
    {
      "type": "math_studio_card",
      "data": {
        "title": "Bảng biến thiên: y = x³ - 3x + 1",
        "rawText": "TXD: R | y' = 3x² - 3 = 0 <=> x = ±1 | CĐ: (-1, 3), CT: (1, -1)",
        "svgContent": "<svg ...>...</svg>",
        "imageBase64": "data:image/svg+xml;base64,...",
        "aspectRatio": 1.77
      }
    }
    ```
- Nâng cấp phía Flutter Host theo kiến trúc Microkernel thuần túy (**TUYỆT ĐỐI TUÂN THỦ RULE 1 `AGENTS.md` - ZERO HARDCODED NAMES**):
  - Trong `frontend/lib/features/studio_board/domain/models/board_sticker.dart`:
    - Bổ sung các trường tùy chọn: `final String? title`, `final String? svgContent`, `final String? imageBase64`.
    - Cập nhật `toJson` và `fromJson` tương thích ngược 100% với dữ liệu hiện có.
  - Trong `frontend/lib/features/plugin_engine/services/host_bridge.dart`:
    - Trích xuất `title`, `svgContent`, `imageBase64` từ `payload['data']` nạp vào `BoardSticker`.
  - Trong `frontend/lib/features/studio_board/presentation/board_sticker_card.dart`:
    - Tiêu đề card: Sử dụng `sticker.title ?? 'Ghi chú bài học'` (thay thế chuỗi cố định `'Cú pháp Tiếng Anh (S-V-O)'`).
    - Thân card:
      - Nếu có `svgContent` hoặc `imageBase64`: Render ảnh vector sắc nét (dùng `Image.memory` giải mã base64 hoặc `SvgPicture.string` từ `flutter_svg`).
      - Nếu có `tokens`: Render danh sách tokens ngữ pháp (giữ nguyên logic tiếng Anh hiện tại).
      - Nếu chỉ có `rawText`: Hiển thị đoạn text tóm tắt.
    - Tuyệt đối không có bất kỳ câu lệnh `if (sticker.type == 'com.hocluc.plugin.math_studio')` nào trong code Flutter! Host hoàn toàn generic và mở rộng cho mọi plugin tương lai.

---

## 2. Tiêu Chí Nghiệm Thu (Acceptance Criteria)
- [ ] Bấm nút "Chèn vào bảng" trong Webview $\to$ Studio Board nhận được sticker ngay lập tức.
- [ ] Sticker hiển thị trên bảng phấn đúng hình ảnh đồ thị / bảng biến thiên, có thanh tiêu đề kéo thả, nút xóa.
- [ ] Giáo viên có thể di chuyển sticker, thu nhỏ phóng to và dùng bút phấn viết đè lên sticker bình thường.
- [ ] Không có bất kỳ chuỗi tên plugin nào bị hardcode trong `frontend/lib/`.
- [ ] Chạy `flutter test test/features/studio_board/board_sticker_test.dart` đạt 100% PASS.
