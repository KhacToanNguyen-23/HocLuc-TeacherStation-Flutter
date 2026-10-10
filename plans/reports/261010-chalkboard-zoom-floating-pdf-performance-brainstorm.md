# Brainstorm: Chalkboard Compact Grid, Pan/Zoom, Free-Floating PDF, Laser Trail, Page Management & Zero-Latency Inking

**Date:** 2026-10-10

## Ideas Explored

1. **Kích thước ô bảng (Chalkboard Grid):**
   - *Option A (Giữ 24px):* Ô to nhanh hết bảng.
   - *Option B (Thu nhỏ về 15px chuẩn vở ô ly):* Tăng sức chứa gấp 2.5–3 lần, phù hợp viết nhiều công thức và lời giải dài. (Đã chọn)

2. **Cơ chế Thu phóng & Di chuyển bảng (Pan & Zoom):**
   - *Option A (Touch Gestures):* Dễ cấn mu bàn tay, không tối ưu cho bảng vẽ thông thường.
   - *Option B (Space + Drag để Pan, Con lăn / Ctrl+Wheel để Zoom):* Chuẩn mực công nghiệp, tối ưu hoàn hảo cho giáo viên cầm bút vẽ stylus. (Đã chọn)

3. **Bố cục hiển thị tài liệu PDF trên bảng:**
   - *Option A (Split Screen 50/50 cố định):* Gò bó, chiếm nửa màn hình.
   - *Option B (Cửa sổ nổi - Free-floating Draggable Window):* Giữ thanh header kéo thả PDF đến bất cứ đâu, resize góc, chuyển trang và đóng về khay tài liệu bất kỳ lúc nào. (Đã chọn)

4. **Triệt tiêu độ trễ và giật lag khi viết (Inking Performance):**
   - *Option A (Single-layer repaint all strokes):* Đang dùng hiện tại — mỗi frame tính toán lại toàn bộ lịch sử nét vẽ dẫn đến O(N) CPU load gây lag nặng.
   - *Option B (Dual-layer Canvas Architecture):* Tách nét cũ (đã hoàn thành, cache Path tĩnh/Picture) và nét đang viết (active stroke trong RepaintBoundary riêng), giảm 95% thời gian render, đạt 60fps–120fps mượt mà. (Đã chọn)

5. **Công cụ Trợ giảng Bổ sung (Teacher Engagement Tools):**
   - **Laser Trail (Nét laser tự tan biến):** Vẽ đường laser phát sáng để hướng sự chú ý của học sinh, tự mờ và biến mất sau 1–2 giây mà không lưu vết bẩn bảng. (Đã chọn)
   - **Bút dạ quang (Highlighter):** Độ trong suốt (translucent alpha ~0.35) làm nổi bật định nghĩa/từ khóa mà không che lấp chữ bên dưới. (Đã chọn)
   - **Quản lý trang (Page Next/Prev) & Undo/Redo:** Phân tách dữ liệu nét vẽ độc lập từng trang bảng, hỗ trợ hoàn tác và làm lại (Undo/Redo stack) chuẩn xác. (Đã chọn)

## User's Direction

- Sử dụng **phím `Space` hoặc nút phụ trên thân bút để kéo bảng (Pan)**, dùng **con lăn chuột (hoặc `Ctrl + Scroll`) để Zoom in / Zoom out** mượt mà.
- File PDF sau khi kéo ra sẽ là cửa sổ nổi tự do: **giữ thanh header kéo thả** đến bất cứ vị trí nào trên bảng mà không cố định trái hay phải.
- Thu nhỏ kích thước ô ly bảng (15px) để viết được nhiều bài giảng hơn.
- Triệt tiêu độ trễ và lag khi vẽ trên bảng và PDF bằng kiến trúc Dual-layer.
- Thêm **Con trỏ laser (Laser Trail)** phát sáng tự biến mất sau 1–2 giây.
- Thêm **Chuyển trang (Page Next/Prev)** lưu nét độc lập từng trang.
- Thêm **Undo / Redo** chuẩn xác từng trang.
- Thêm **Bút dạ quang (Highlighter)** có độ trong suốt nổi bật chữ bên dưới.

## Open Questions & Decisions

- **Laser Trail Duration:** 1.5 giây kể từ khi vung nét, fade-out mượt bằng animation ticker/timer.
- **Undo/Redo Scope:** Hoạt động độc lập trên trang bảng đang active (hoặc trang PDF đang active).
- **Giới hạn Zoom:** 50% – 300%, mặc định 100%.

## Risks & Mitigations

1. **Rủi ro rò rỉ bộ nhớ từ Laser Trail timer:**
   - *Khắc phục:* Sử dụng ticker/single periodic timer làm sạch các điểm laser quá hạn, tự động dừng khi không có nét laser nào hoạt động.
2. **Rủi ro mất dữ liệu nét khi chuyển trang:**
   - *Khắc phục:* Cấu trúc dữ liệu `pages[pageIndex]` độc lập, lưu trữ state toàn vẹn trước khi đổi `pageIndex`.
