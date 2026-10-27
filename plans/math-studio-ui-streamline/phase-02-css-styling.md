# Phase 2: CSS Styling, Triệt tiêu Thanh cuộn & Header Tabs

**File:** `plugins/math_studio/ui/style.css`  
**Stories Covered:** P1 (Triệt tiêu thanh cuộn ngang), P2 (Header vừa vặn)  

### Tasks:
1. Thêm CSS cho Accordion:
   - `.advanced-accordion-card`
   - `.accordion-header-btn` (màu chữ `#0B3A82`, hover mềm)
   - `.accordion-arrow` (xoay 180 độ khi mở)
   - `.accordion-body`
2. Khóa chặt `.left-controls-col`:
   - `overflow-x: hidden !important`
   - `box-sizing: border-box`
3. Định kiểu `.vp-grid-2col`:
   - `display: grid; grid-template-columns: 1fr 1fr; gap: 6px 8px;`
   - Input fields: `width: 100%; min-width: 0; box-sizing: border-box;`
4. Tinh chỉnh Header:
   - Co nhẹ padding `.mode-tab-nav` và `.mode-tab` (`padding: 3px 8px`, `font-size: 11.5px`) để 4 tab hiển thị sắc nét, không chạm mép phải.

