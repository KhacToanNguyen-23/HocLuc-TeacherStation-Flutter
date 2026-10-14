# Phase 01: Visual Channel Separation & Span Conflict Resolution in Flutter UI

**Phase ID:** `phase-01-visual-channel-separation`
**Priority:** P1
**Objective:** Triển khai cơ chế phân tách kênh đồ họa thị giác cho các tầng kiến thức lồng nhau trên [`PdfDgnlPassageOverlay`](file:///d:/6_OJT/HocLuc-TeacherStation-Flutter/frontend/lib/widgets/pdf_dgnl_passage_overlay.dart), loại bỏ hoàn toàn hiện tượng chồng đè màu nền giữa Ngữ pháp, Collocation và Từ vựng.

---

## Detailed Tasks

1. **Spatial & Range Containment Helper:**
   - Trong `pdf_dgnl_passage_overlay.dart`, xây dựng hàm kiểm tra quan hệ bao hàm giữa hai span:
     `bool isSpanContained(PdfDgnlHighlightSpan inner, PdfDgnlHighlightSpan outer)` dựa trên `normalizedRects` và offset text.
2. **Visual Channel Allocation Rules:**
   - **Tầng Ngữ pháp (Grammar):** 
     - Vẽ bằng `_DashedBorderPainter` (nét đứt màu xanh dương `#89b4fa`), độ dày nét `1.8px`.
     - Màu nền: `Colors.transparent` (0% opacity fill) để không che bất kỳ nội dung nào bên dưới.
     - Kích thước khung viền mở rộng nhẹ `margin: -2px` bao trọn cụm từ.
   - **Tầng Cụm từ (Collocation):**
     - Vẽ bằng `BoxDecoration` có màu nền xanh lá pastel dịu (`#86efac` với alpha `0.22`), `borderRadius: BorderRadius.circular(4.0)`.
     - Viền bo mờ bao quanh `0.8px` (alpha `0.4`), không dùng đường gạch chân phẳng đáy để tránh đè lên gạch chân của đề thi gốc.
   - **Tầng Từ vựng (CEFR B2 / C1):**
     - *Nếu đứng độc lập:* Vẽ bằng khối màu pastel vàng ấm (`#f9e2af` alpha `0.22`) cho B2, tím pastel (`#cba6f7` alpha `0.22`) cho C1.
     - *Nếu nằm lọt trong một cụm Collocation:* Tự động chuyển sang chế độ **viền bo mỏng không nền** (`Border.all(color: accentColor.withValues(alpha: 0.8), width: 1.2)`, `color: Colors.transparent`). Điều này đảm bảo từ vựng vẫn được nhận diện rõ ràng mà không tạo ra mảng màu xanh vàng pha trộn gây đục chữ.
3. **Ghosting / Dimming khi lọc Tab:**
   - Khi chọn một tab chuyên biệt (ví dụ chỉ chọn `Ngữ pháp` hoặc `B2`):
     - Các span thuộc danh mục đang chọn giữ `opacity: 1.0` và viền sáng rõ.
     - Các span thuộc danh mục khác tự động giảm `opacity: 0.12` (hiệu ứng bóng mờ nhẹ) thay vì biến mất đột ngột, giúp giáo viên giữ được ngữ cảnh tổng thể của câu văn.

---

## Affected Files

- `frontend/lib/widgets/pdf_dgnl_passage_overlay.dart`
- `frontend/lib/services/dgnl_service.dart`

---

## Dependencies

- Không phụ thuộc vào phase khác. Có thể triển khai và kiểm thử độc lập phía Flutter UI.

---

## Tests and Acceptance Criteria

- Chạy lệnh: `flutter test test/dgnl_snip_highlight_test.dart`
- Đoạn văn có `used to suffer` (chứa `used to` ngữ pháp và `suffer` từ vựng) và `passive smoking` (chứa `smoking` từ vựng):
  - Khung nét đứt bao quanh `used to suffer` có nền hoàn toàn trong suốt.
  - Cụm `passive smoking` có nền màu xanh lá pastel dịu.
  - Từ `smoking` bên trong cụm không có màu nền thứ hai đè lên.
  - Chữ in gốc của PDF đọc rõ ràng 100%.
