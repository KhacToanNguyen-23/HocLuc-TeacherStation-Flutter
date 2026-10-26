# Spec: Đồ Thị Biến Dạng & Uốn Lượn Động Theo Điểm Cực Trị (Dynamic Curve Morphing)

## 1. Problem Statement
Hiện tại, khi giáo viên kéo điểm cực tiểu từ $(0, -2)$ sang $(1.2, -3)$:
- Điểm tròn màu xanh di chuyển nhưng đường cong màu đỏ $y = x^2 - 2$ vẫn đứng yên tại chỗ, khiến điểm cực trị bị lơ lửng ngoài đường cong.
- Nhãn điểm vẫn giữ tọa độ cũ `CT (0; -2)`.
- Thẻ công thức góc trái vẫn giữ `y = x^2 - 2`.
Người dùng yêu cầu: Khi kéo cực đại / cực tiểu, đường cong đồ thị PHẢI thay đổi và uốn lượn theo ngay lập tức, đỉnh đường cong dính chặt vào con trỏ chuột.

## 2. Requirements & User Stories

### P1: Đường Cong Uốn Lượn Động (60 FPS Curve Morphing)
- **US1.1:** Hàm vẽ `functiongraph` trong JSXGraph sử dụng getter động: `(x) => options.getEval()(x)`.
- **US1.2:** Khi giáo viên kéo điểm cực trị, sự kiện `drag` gọi `computeFormulaFromDrag(currentAnalysis, handle, x, y)` để giải nghịch đảo ra công thức hàm số mới.
- **US1.3:** Cập nhật `currentAnalysis` và kích hoạt `board.update()` để đường cong vẽ lại ngay lập tức tại vị trí chuột. Đỉnh của parabol hoặc cực trị hàm bậc 3 luôn dính chặt 100% vào điểm cực trị.

### P1: Nhãn Tọa Độ & Huy Hiệu Công Thức Nhảy Số Theo Thời Gian Thực
- **US2.1:** Nhãn của điểm cực trị hiển thị tọa độ động: `() => `${ext.type} (${Number(extPt.X().toFixed(1))}; ${Number(extPt.Y().toFixed(1))})``.
- **US2.2:** Huy hiệu công thức góc trái tự động cập nhật công thức mới tương ứng theo thời gian thực (ví dụ $y = x^2 - 2.4x - 1.56$).
- **US2.3:** Ô nhập hàm số `mathInput.value` và ô tọa độ trong `extremaEditorContainer` đồng bộ số liệu tức thời.

### P1: Kiểm Thử & Bất Biến Kiến Trúc
- **US3.1:** 5/5 test suites logic đạt PASS 100%.
- **US3.2:** Đóng gói `plugins/math_studio.hlep` đồng bộ 100%.
- **US3.3:** 12/12 Bất biến kiến trúc đạt PASS 100%.

## 3. Success Criteria
- Khi kéo điểm cực trị, đường cong uốn lượn liên tục theo ngón tay/chuột (không bị tách rời 1 pixel nào).
- Nhãn điểm cập nhật tọa độ liên tục theo vị trí chuột.
- Thẻ công thức và ô nhập liệu bên trái hiển thị chính xác phương trình mới.

