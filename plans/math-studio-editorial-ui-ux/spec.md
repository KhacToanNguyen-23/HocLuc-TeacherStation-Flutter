# Spec: Math Studio Editorial UI & Zero-Latency UX Redesign

**Date:** 2026-10-27  
**Status:** Ready

---

## Problem Statement
Giao diện hiện tại của Học Lực Math Studio bị lỗi thiết kế "hộp lồng trong hộp" (box-in-a-box) với nhiều đường viền xám vụn vặt, ô nhập và khung xem trước công thức bị phân mảnh làm hai, nửa dưới cột tham số để lại khoảng trắng chết lớn, đồng thời thiếu các thông tin khảo sát trọng tâm của SGK GDPT 2018 (khoảng đơn điệu, tâm đối xứng) và độ trễ phản hồi khi gõ/thao tác cần được tối ưu xuống mức tức thì (< 16ms).

---

## User Stories

<!-- P1 = MVP (must ship), P2 = nice-to-have, P3 = future/out-of-scope -->

- **[P1]** As a teacher, I want a unified Hero Formula Input block so that I can type and see an elegant mathematical expression without redundant gray preview boxes cluttering the workspace.
  Accepted when: The formula input is a single unified block with STIX/Cambria typography, clear button, and an integrated bottom micro-bar showing $y'$ and $D$.

- **[P1]** As a teacher, I want an Editorial Pedagogical Inspector displaying Monotonicity Intervals ($\nearrow, \searrow$), Extrema ($CĐ, CT$), Symmetry/Inflection ($I$), and Asymptotes so that I have the complete standard SGK 2018 function analysis at a glance without dead empty space.
  Accepted when: The left inspector displays all 4 pedagogical pillars cleanly separated by hairline dividers, automatically populated from CAS analysis with 0 dead vertical space.

- **[P1]** As a teacher, I want zero-latency interaction (< 16ms) when modifying formulas, toggling properties, or selecting points so that the graph board responds instantly without spinners or frame drops.
  Accepted when: In-place JSXGraph updates execute in < 1ms, formula debounce is set to 80ms with instant input mirroring, and point clicks highlight interactively at 60fps.

- **[P2]** As a teacher, I want interactive linking between property rows and graph elements so that clicking an extremum, inflection point, or intercept immediately focuses and flashes that point on the coordinate plane.
  Accepted when: Clicking any row in the property inspector highlights the corresponding point and coordinate projections on the board.

- **[P3]** Interactive parameter slider (thanh trượt tham số m) for animated function families.

---

## Functional Requirements

1. **FR-01: Unified Hero Formula Input**
   - Thay thế cặp đôi `formula-input-row` + `math-live-preview-box` bằng 1 khối duy nhất.
   - Hiển thị tiền tố $y =$, ô nhập text linh hoạt, nút xóa $\times$, và micro-bar hiển thị gọn: Đạo hàm $y'$, TXĐ $D$, nút ký hiệu $\sum$.

2. **FR-02: Pedagogical Analysis Expansion in CAS**
   - Mở rộng [math_cas.js](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/plugins/math_studio/ui/core/math_cas.js) để tự động tính:
     - **Khoảng đơn điệu**: Xác định các khoảng $y' > 0$ ($\nearrow$) và $y' < 0$ ($\searrow$) dựa trên nghiệm của đạo hàm và điểm gián đoạn.
     - **Tâm đối xứng / Điểm uốn $I(x_0, y_0)$**: Đối với hàm bậc 3 giải $f''(x) = 0$; đối với hàm phân thức lấy giao điểm của tiệm cận đứng và tiệm cận xiên/ngang.

3. **FR-03: Editorial Inspector Layout (32% : 68%)**
   - Tái cấu trúc [index.html](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/plugins/math_studio/ui/index.html) và [style.css](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/plugins/math_studio/ui/style.css):
     - Loại bỏ các card bo viền độc lập lồng nhau (`param-card`).
     - Sử dụng bố cục phân mục dọc (Semantic Sections) ngăn cách bằng đường kẻ tóc `rgba(15, 23, 42, 0.065)`.
     - Cột đồ thị bên phải chiếm 68% diện tích, mở rộng tối đa tầm nhìn cho giáo viên.

4. **FR-04: Interactive Point Linking**
   - Click vào bất kỳ hàng nào trong danh sách (Cực trị, Giao trục, Điểm uốn) sẽ highlight điểm đó trên JSXGraph board và vẽ đường gióng tọa độ nét đứt.

---

## Non-Functional Requirements

- **Performance**:
  - CAS Analysis & Monotonicity calculation: $\le 3\text{ms}$.
  - In-place Board Curve & Element update: $\le 1\text{ms}$.
  - DOM Render pipeline: $\le 2\text{ms}$.
  - Tổng độ trễ tương tác: $\le 16\text{ms}$ (chuẩn 60fps).
- **Visual Design**:
  - Không viền hộp thô (Zero Box-in-a-Box).
  - Tỷ lệ phân chia 32% Inspector : 68% Canvas.
  - Typography: Font STIX Two Math / Cambria Math cho công thức số học, Segoe UI Variable cho nhãn sư phạm.
- **Architecture Invariants**:
  - Không hardcode ID plugin trong core Flutter.
  - Tuân thủ nghiêm ngặt Schema v2.1, 12/12 bài test `architecture_test.dart` vượt qua.

---

## Success Criteria

- [ ] Cột trái hiển thị đầy đủ 4 phân khu sư phạm SGK mà không có khoảng trống trắng chết ở đáy.
- [ ] Ô nhập hàm là 1 khối duy nhất, loại bỏ hoàn toàn box preview màu xám trùng lặp.
- [ ] Tính toán chính xác khoảng đồng biến, nghịch biến và điểm uốn cho các hàm phổ biến (bậc 3, bậc 4 trùng phương, phân thức bậc 1/1 và 2/1).
- [ ] Thao tác gõ biểu thức và chuyển đổi thông số phản hồi mượt mà không có độ trễ cảm nhận được (< 16ms).
- [ ] Chạy `flutter test test/architecture_test.dart` đạt 12/12 passing invariants.
- [ ] Chạy `flutter analyze --no-fatal-infos` đạt 0 errors, 0 warnings.

---

## Out of Scope
- Dựng bảng biến thiên toàn phần ở chế độ đồ thị (Bảng biến thiên đầy đủ đã có tab chuyên biệt `BBT`).
- Chỉnh sửa đồ thị bằng kéo thả chuột trực tiếp trên đường cong (chỉ hỗ trợ rê kéo cận tích phân $a, b$ và kéo rê hệ trục).

---

## Assumptions
- Trình duyệt/Webview hỗ trợ ES2022 và CSS Flexbox hiện đại.
- Biểu thức đầu vào tuân thủ cú pháp đại số chuẩn (hỗ trợ `^`, `*`, `/`, `sqrt`, `sin`, `cos`).

