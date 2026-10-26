# Phase 1: Tái cấu trúc HTML Cột Trái & Accordion

**File:** `plugins/math_studio/ui/index.html`  
**Stories Covered:** P1 (Core layout clean), P2 (Accordion structure)  

### Tasks:
1. Đặt thẻ HÀM SỐ ở vị trí đầu tiên.
2. Đặt thẻ ĐIỂM ở vị trí thứ hai.
3. Tạo khối Accordion `#advancedAccordion`:
   - Header button: `#btnToggleAdvanced` với nhãn `Tùy chọn nâng cao` và icon `▾`.
   - Body container: `#advancedAccordionBody` (class `hidden`).
4. Di chuyển thẻ `VẬT THỂ TRÒN XOAY`, `KHUNG NHÌN`, `MIỀN NGHIỆM` vào bên trong `#advancedAccordionBody`.
5. Đổi cấu trúc input của KHUNG NHÌN sang `vp-grid-2col`:
   - Cột 1: $x \text{ từ}$, $y \text{ từ}$, Mỗi vạch $x$.
   - Cột 2: $x \text{ đến}$, $y \text{ đến}$, Mỗi vạch $y$.

