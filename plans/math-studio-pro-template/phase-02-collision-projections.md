# Phase 2: Triệt Tiêu Đè Chữ & Đường Gióng Nét Đứt SGK

**File:** `plugins/math_studio/ui/render/graph_plotter.js`  
**Stories Covered:** P1 (Triệt tiêu 100% đè chữ, đường gióng SGK)  

### Tasks:
1. Từ mỗi điểm cực trị $(x, y)$:
   - Vẽ 2 đường gióng nét đứt vuông góc:
     - Xuống $Ox$: từ $(sx, sy)$ đến $(sx, originY)$
     - Xuống $Oy$: từ $(sx, sy)$ đến $(originX, sy)$
     - Thuộc tính: `stroke="#94a3b8"`, `stroke-width="1.1"`, `stroke-dasharray="3,3"`, `opacity="0.8"`.
2. Chấm điểm cực trị:
   - Chấm tròn: `r="4.5"`, `fill="#0b3a82"`, viền trắng `stroke="#ffffff"`, `stroke-width="2"`, đổ bóng nhẹ `filter="drop-shadow(0 1px 2px rgba(0,0,0,0.2))"`.
3. Nhãn điểm cực trị:
   - Tự động kiểm tra: nếu là Cực tiểu $CT$ $\to$ đặt nhãn phía dưới điểm hoặc lệch góc; nếu là Cực đại $CĐ$ $\to$ đặt nhãn phía trên điểm.
   - Khoảng cách offset: $8px$, không in tọa độ dài dòng dính vào điểm để tránh đè chữ.
4. Mút tích phân $a, b$:
   - Đặt nhãn $a = -1$, $b = 2$ ở vị trí `originY + 18`, căn giữa.
   - Không cho phép nhãn mút đè lên hoành độ giao điểm (nếu trùng vị trí, tự động dịch chuyển hoặc ẩn hoành độ giao điểm phụ).

