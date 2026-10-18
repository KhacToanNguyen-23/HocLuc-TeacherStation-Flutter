# Brainstorm: Chế Độ Hiển Thị Sát Viền (Frameless Device Mode) Cho Plugin Máy Tính Casio

**Date:** 2026-10-17

## Ideas Explored

1. **Hướng A — Cắt bỏ khung trang web trực tiếp trong gói Casio nhưng vẫn giữ khung cửa sổ nổi của Flutter:**
   - Ẩn header `hocluc.com` và footer bản quyền trong HTML/CSS của Casio, nhưng vẫn còn thanh tiêu đề `🧩 Máy Tính Khoa Học Casio` bên trên của `FloatingPluginWindow`.
   - *Đánh giá:* Chưa triệt để vì vẫn còn cảm giác một hộp cửa sổ máy tính chứ chưa phải chiếc máy tính cầm tay thật đặt trên bảng phấn.

2. **Hướng B — Chuẩn hóa chế độ `"frameless": true` trong Manifest Schema v2.1 + CSS Sát Viền Thân Máy (Được chọn):**
   - Bổ sung cờ `"frameless": true` vào `manifest.json` (cho phép bất kỳ plugin dạng thiết bị mô phỏng nào như Máy tính Casio, Thước đo góc, Đồng hồ bấm giờ đều dùng được mà không hardcode trong `frontend/lib/`).
   - Khi `frameless: true`, `FloatingPluginWindow` ẩn hoàn toàn khung nền và thanh tiêu đề rời rạc bên ngoài, bo góc khớp đúng vỏ máy (`borderRadius: 24px`) và tích hợp vùng nắm kéo + nút Đóng (`×`) nhỏ gọn ngay trên gờ trên của thân máy Casio.
   - Trong gói `plugins/casio_calculator`, nạp CSS chế độ nhúng (`embed.css`) ẩn hoàn toàn `.calculator-app-heading` (`hocluc.com`, các icon menu), ẩn `.calculator-copyright`, xóa bỏ toàn bộ lề trắng (`#edf1f5`) để thân máy `.calc-face` lấp đầy 100% khung hiển thị.

3. **Hướng C — Thanh điều khiển ẩn hiện khi rê chuột (Hover Overlay):**
   - Chỉ hiện nút đóng và thanh kéo khi di chuột lên đỉnh máy.
   - *Đánh giá:* Kém thuận tiện hơn trên màn hình cảm ứng / bảng tương tác thông minh (Interactive Flat Panel) nơi giáo viên dùng ngón tay hoặc bút cảm ứng không có trạng thái hover.

## User's Direction

- Người dùng muốn hiển thị **"chỉ đúng thân máy tính"**, loại bỏ hoàn toàn phần nền trắng bao quanh, thanh menu `hocluc.com`, dòng bản quyền dưới đáy và thanh tiêu đề cửa sổ thô cứng.
- Thao tác kéo di chuyển & nút Đóng (`×`) được tích hợp gọn gàng ngay trên gờ trên của thân máy Casio.
- Cấu hình thông qua thuộc tính `"frameless": true` trong `manifest.json` kết hợp CSS thu gọn thân máy trong gói `plugins/casio_calculator` để giữ chuẩn Zero-Hardcode cho Core.

## Open Questions

- Không còn điểm mờ (`0 [NEEDS CLARIFICATION]`). Đã sẵn sàng chuyển sang bước lập kế hoạch (`$bb-plan`) và triển khai (`$bb-cook`).

## Risks

1. **Cơ chế co giãn tự động (`--calculator-scale`) của ứng dụng Casio Vite:**
   - Bản build gốc của Casio dùng biến CSS `--calculator-scale` và `transform: translate(-50%, -50%) scale(...)` trên `.calc-playground-face` dựa theo kích thước của `.calculator-fit-stage`. Khi ẩn header và footer, cần đảm bảo `.calculator-fit-stage` và `.calc-face` vừa khít khung cửa sổ (`328x556`) mà không bị cắt mất hàng phím cuối (`0`, `.`, `=`) hay màn hình LCD.
2. **Không cho sự kiện chuột của WebView nuốt thao tác kéo trên gờ trên thân máy:**
   - Vùng nắm kéo (Drag Bezel) và nút Đóng (`×`) cần được vẽ bằng widget Flutter nằm đè lên mép trên (`top: 0`, cao ~26px) của thân máy để giáo viên kéo bằng chuột hoặc ngón tay mượt 60fps trên Windows WebView2.

