# Spec: Nâng Cấp Template Đồ Thị Chuẩn Pro (Hybrid Desmos + SGK)

**Date:** 2026-10-26  
**Status:** Ready  

---

## Problem Statement
Đồ thị hàm số hiện tại bị mờ nhòe chữ số trục (9px xám nhạt), các nhãn điểm và mút tích phân đè chồng chữ lên nhau làm mất tính thẩm mỹ, miền tích phân dùng sọc chéo thô ráp kiểu CAD và công thức hiển thị dạng text thô `x^2 - 2`. Cần nâng cấp toàn diện template đồ thị theo chuẩn Hybrid hiện đại (Desmos Typography + SGK Pedagogical Projection).

---

## User Stories

- **[P1]** Là một giáo viên, tôi muốn nhìn thấy các chữ số trên trục $Ox, Oy$ to rõ, sắc nét, tương phản cao (font 11.5px–12px, màu xám đậm `#1F2937`) để học sinh ngồi xa bảng vẫn đọc được rõ ràng.  
  *Accepted when:* Chữ số trục tọa độ hiển thị sắc nét, không bị nhòe pixel, tương phản đạt chuẩn WCAG AA trên nền trắng và bảng đen.

- **[P1]** Là một giáo viên, tôi muốn triệt tiêu 100% hiện tượng đè chữ tại điểm cực trị và trục hoành; các điểm uốn/cực trị có đường gióng nét đứt vuông góc xuống trục $Ox, Oy$ chuẩn sư phạm SGK.  
  *Accepted when:* Không có bất kỳ nhãn text nào đè lên nhau tại điểm cực trị hoặc các mút cận tích phân. Điểm cực trị hiển thị chấm viền trắng tinh tế kèm đường gióng vuông góc xuống 2 trục.

- **[P1]** Là một giáo viên dạy bài Tích phân diện tích, tôi muốn miền tích phân được tô màu phẳng bán trong suốt cao cấp (Translucent Flat Tint 15%–18%) thay vì sọc chéo CAD thô ráp cũ kỹ.  
  *Accepted when:* Miền diện tích hình phẳng được phủ màu trong suốt mượt mà, đường sinh biên $x=a$ và $x=b$ vẽ nét đứt thanh mảnh (1.2px) chuẩn mực.

- **[P2]** Là một giáo viên, tôi muốn nhãn công thức ở góc đồ thị hiển thị chuẩn toán học ($y = x^2 - 2$ với số mũ $2$ superscript, hoặc phân thức đẹp mắt) thay vì viết code thô `x^2 - 2`.  
  *Accepted when:* Công thức hiển thị số mũ superscript chuẩn toán học, màu sắc đồng bộ với đường đồ thị.

- **[P2]** Là một giáo viên, tôi muốn gốc tọa độ $O$ và các mũi tên trục $x, y$ được thiết kế thanh mảnh, đặt đúng góc phần tư thứ III chuẩn sách giáo khoa.  
  *Accepted when:* Gốc $O$ nằm ở vị trí cân đối $(originX - 10, originY + 13)$, mũi tên trục $Ox, Oy$ sắc nét không thô cứng.

---

## Functional Requirements

1. **FR-01 (Nâng cấp Typography & Trục số):**
   - Đổi font chữ số trục sang Sans-serif hệ thống hiện đại (`font-size: 11.5px`, `font-weight: 500`, `fill: #1F2937`).
   - Căn chỉnh vị trí nhãn trục $x$: cách trục 14px; trục $y$: cách trục 8px căn phải (text-anchor: end).
   - Tối ưu đường lưới: Nét mảnh 0.8px, màu `rgba(15, 23, 42, 0.08)` hoặc `#E2E8F0`, căn chỉnh sub-pixel để chống mờ.
2. **FR-02 (Hệ thống Chống đè chữ & Đường gióng SGK):**
   - Tại điểm cực trị $(x_0, y_0)$:
     - Vẽ đường gióng nét đứt từ $(x_0, y_0)$ xuống $(x_0, 0)$ trên $Ox$ và $(0, y_0)$ trên $Oy$ (`stroke: #94A3B8`, `stroke-width: 1.2px`, `stroke-dasharray: 3,3`).
     - Điểm chấm: Chấm tròn đường kính 8px, viền trắng 2px (`stroke: #FFFFFF`, `stroke-width: 2px`), màu thương hiệu `#0B3A82`, có đổ bóng nhẹ.
     - Nhãn điểm: Đặt nhãn $CĐ$ hoặc $CT$ cách đỉnh 8px về phía ngoài đường cong (không đè lên đỉnh).
   - Tại mút tích phân $a$ và $b$:
     - Đặt nhãn $a = ...$ và $b = ...$ ở dưới trục $Ox$ (cách trục 18px), căn giữa mút cận, không đè lên các số tick của trục.
3. **FR-03 (Tô màu Miền diện tích Tích phân Hiện đại):**
   - Loại bỏ thẻ `<pattern id="hatchPattern">` sọc chéo thô cũ.
   - Dùng dải màu phẳng bán trong suốt `fill="rgba(224, 36, 36, 0.16)"` (trên nền sáng) hoặc `rgba(56, 189, 248, 0.22)` (trên bảng phấn).
   - Hai vạch giới hạn $x = a$ và $x = b$ dựng thẳng đứng với nét đứt thanh mảnh $1.2px$.
4. **FR-04 (Công thức Toán học chuẩn Superscript):**
   - Xử lý chuỗi công thức: Chuyển các ký hiệu `^2`, `^3`, `^n` thành các thẻ `<tspan dy="-4" font-size="80%">n</tspan><tspan dy="4">...</tspan>` trong SVG để hiển thị số mũ đẹp mắt.

---

## Non-Functional Requirements

- **Độ sắc nét:** Không bị nhòe răng cưa trên màn hình Retina / 4K.
- **Tốc độ:** Tái kết xuất đồ thị tức thì dưới 10ms khi người dùng kéo nắn đồ thị.
- **Bất biến kiến trúc:** Không import trực tiếp, 100% tuân thủ AGENTS.md.

---

## Success Criteria

- [ ] Số trên trục tọa độ hiển thị sắc nét với font 11.5px, màu `#1F2937`, không còn nhòe mờ.
- [ ] 0 trường hợp đè chữ tại đỉnh cực trị và các mút giao điểm trên toàn bộ các hàm số mẫu (bậc 2, bậc 3, phân thức).
- [ ] Miền tích phân hiển thị dạng màu trong suốt hiện đại (không còn sọc chéo CAD).
- [ ] Công thức góc đồ thị hiển thị số mũ superscript $y = x^2 - 2$ chuẩn toán học.
- [ ] Toàn bộ bộ test kiến trúc và plugin validator đạt 100% PASS.

