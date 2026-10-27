# Phase 02: Strict XML SVG Generation & Prominent [📌 Ghim vào bảng] Action

**Status:** Not Started  
**Target Files:**
- `plugins/math_studio/ui/render/graph_plotter.js`
- `plugins/math_studio/ui/index.html`
- `plugins/math_studio/ui/app.js`
- `plugins/math_studio/ui/style.css`
- `scripts/test_math_studio.mjs`
- `scripts/test_app_logic.mjs`

---

## Technical Details

1. **`graph_plotter.js` (`generateGraphSvg`):**
   - Sửa dòng 751:
   ```javascript
   // Thay vì:
   // const formattedSvg = formulaRaw.replace(/\^([0-9a-zA-Z]+)/g, '<tspan dy="-4.5" font-size="9.5">$1</tspan><tspan dy="4.5">');
   // Chuyển thành cặp thẻ đóng XML chuẩn:
   const formattedSvg = formulaRaw.replace(/\^([0-9a-zA-Z]+)/g, '<tspan font-size="75%" dy="-4.5">$1</tspan><tspan dy="4.5">&#x200B;</tspan>');
   // Hoặc:
   const formattedSvg = formulaRaw.replace(/\^([0-9a-zA-Z]+)/g, '<tspan baseline-shift="super" font-size="70%">$1</tspan>');
   ```
   - Kiểm tra `tspanOpens === tspanCloses` trong 100% trường hợp.

2. **`index.html` & `style.css` (Nút Ghim vào bảng):**
   - Cập nhật `#btnDoneDialog`:
   ```html
   <button id="btnDoneDialog" class="btn-dialog-done btn-primary-pin" title="Ghim đồ thị lên bảng chalkboard (Ctrl + Enter)">📌 Ghim vào bảng</button>
   ```
   - Thêm styling nổi bật cho `.btn-primary-pin`: background gradient xanh sang trọng, đổ bóng nhẹ, hover scale tinh tế.

3. **`app.js` (Phím tắt `Ctrl + Enter`):**
   - Lắng nghe sự kiện `keydown` trên `window`: nếu `(e.ctrlKey || e.metaKey) && e.key === 'Enter'`, gọi ngay `handlePinToBoard()`.

4. **Đóng gói & Kiểm tra:**
   - Đóng gói lại: `node scripts/validate_plugins.mjs --fix`.
   - Chạy toàn bộ test suites và kiểm tra kiến trúc.

---

## Verification
- `node scripts/validate_plugins.mjs`: PASS 100%
- `node scripts/run_architecture_check.mjs`: PASS 12/12 Invariants
- `flutter test test/architecture_test.dart`: PASS 12/12 Invariants
- `flutter analyze --no-fatal-infos`: 0 errors, 0 warnings

