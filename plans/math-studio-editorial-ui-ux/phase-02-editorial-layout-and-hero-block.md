# Phase 02: Hero Formula Block & Editorial Inspector (32:68)

**Goal:** Tái cấu trúc toàn bộ giao diện HTML và CSS của Math Studio thành bố cục tỷ lệ vàng 32% : 68%, hợp nhất ô nhập hàm và loại bỏ tình trạng hộp lồng trong hộp cùng khoảng trắng chết.

---

## Scope & Target Files
- `plugins/math_studio/ui/index.html`
- `plugins/math_studio/ui/style.css`

---

## Detailed Implementation Tasks

1. **Task 2.1: Tái thiết kế Hero Formula Block trong `index.html`**
   - Loại bỏ ô xem trước xám độc lập (`#mathLivePreviewBox` cũ).
   - Hợp nhất thành khối Hero Formula Display thanh lịch:
     - Header: Nhãn phân loại và huy hiệu TXĐ `#statusInfo`.
     - Trung tâm: Ô hiển thị công thức toán học kích thước lớn với typography STIX Math/Cambria (`#mathLivePreview`).
     - Hàng nhập lệnh: Ô input text gọn nhẹ `#mathInput` với nút xóa nhanh `#btnClearFormula` và nút mở ký hiệu `#btnToggleChips`.
     - Micro-bar phía dưới: Huy hiệu đạo hàm `#derFormulaBadge` và tóm tắt đơn điệu `#monoSummaryBadge`.

2. **Task 2.2: Tái thiết kế Editorial Inspector 5 phân mục SGK trong `index.html`**
   - Thay thế `cardSpecialPoints` bằng Editorial Property Inspector chia làm 5 mục sư phạm rõ ràng với tiêu đề thanh mảnh và đường viền tóc (Hairline Divider):
     1. **CHIỀU BIẾN THIÊN**: Khoảng đồng biến $(\nearrow)$, khoảng nghịch biến $(\searrow)$.
     2. **ĐIỂM CỰC TRỊ**: Tọa độ cực đại ($CĐ$), cực tiểu ($CT$).
     3. **ĐIỂM UỐN & TÂM ĐỐI XỨNG**: Điểm uốn ($U$), Tâm đối xứng ($I$), Trục đối xứng ($\Delta$).
     4. **TIỆM CẬN**: Tiệm cận đứng ($TCĐ$), ngang ($TCN$), xiên ($TCX$).
     5. **GIAO TRỤC & ĐIỂM GẮN**: Giao $Ox, Oy$, các điểm chấm tự do.
   - Bảo tồn toàn bộ ID kết nối: `#btnExtrema`, `#btnOyIntercept`, `#btnAddPoint`, `#extremaEditorContainer`.

3. **Task 2.3: Viết lại hệ thống Style trong `style.css`**
   - Thiết lập tỷ lệ cột: `.studio-params-col` chiếm `flex: 0 0 32%; width: 32%; min-width: 300px; max-width: 330px;`.
   - Cột canvas: `.studio-canvas-col` chiếm `flex: 1 1 68%; width: 68%;`.
   - Triệt tiêu card border thô (`border: none; background: transparent;`). Dùng đường kẻ phân cách `border-bottom: 1px solid rgba(15, 23, 42, 0.065);`.
   - Tạo kiểu dáng hàng thuộc tính tương tác (`.ext-row`): Padding êm ái, hover hiệu ứng nhẹ, hàng được chọn (`.is-selected`) có màu nền xanh phấn dịu và viền xanh SGK tinh tế.
   - Thêm animation phát xung nhịp (`@keyframes sgkPointRipple` và `.sgk-point-pulsing`) cho các điểm trên SVG canvas.

---

## Verification & Criteria
- Trực quan hóa layout trong Webview: Cột trái đầy đặn, không có khoảng trắng chết ở đáy, không còn ô xám trùng lặp.
- Tỷ lệ 32% : 68% phân chia hoàn hảo trên khung hình $960\text{px} \times 560\text{px}$.

