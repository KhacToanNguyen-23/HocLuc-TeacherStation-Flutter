# Phase 1: Nâng cấp Typography, Đường Lưới & Trục Tọa Độ Sắc Nét

**File:** `plugins/math_studio/ui/render/graph_plotter.js`  
**Stories Covered:** P1 (Trục số to rõ, sắc nét, không mờ)  

### Tasks:
1. Nâng cấp bảng màu `colors`:
   - `axis: '#0f172a'`
   - `axisLabel: '#1f2937'` (màu xám đậm, độ tương phản cao trên nền trắng)
   - `grid: '#e2e8f0'` (độ dày 0.8px, sắc sảo)
2. Vòng lặp vẽ số trên trục $Ox$:
   - Font-size: 11.5px, font-weight: 500.
   - Vị trí y: `originY + 14` (cách trục 14px, không dính sát trục).
3. Vòng lặp vẽ số trên trục $Oy$:
   - Font-size: 11.5px, font-weight: 500.
   - Vị trí x: `originX - 7`, text-anchor: `end`.
4. Gốc tọa độ $O$:
   - Đặt tại `originX - 10`, `originY + 13`, font-size: 11.5px, font-weight: bold.
5. Mũi tên đầu trục:
   - Chiều dài 6px, rộng 4px, sắc nét và thanh thoát.

