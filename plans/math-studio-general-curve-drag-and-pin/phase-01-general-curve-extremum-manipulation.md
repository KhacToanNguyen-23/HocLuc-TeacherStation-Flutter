# Phase 01: Dynamic Curve & Extremum Manipulation for General Functions

**Status:** Not Started  
**Target Files:**
- `plugins/math_studio/ui/core/curve_manipulator.js`
- `plugins/math_studio/ui/app.js`
- `scripts/test_curve_manipulator.mjs`

---

## Technical Details

1. **`curve_manipulator.js` (`computeFormulaFromDrag`):**
   ```javascript
   // 6. GENERAL / COMPLEX / HIGH-DEGREE FUNCTIONS (Trigonometric, x^5, etc.)
   if (fnType === 'general') {
     const extrema = analysis.extrema || [];
     if (handle.type === 'extremum' && extrema.length > 0) {
       const dragIdx = handle.idx ?? 0;
       const ext = extrema[dragIdx];
       if (!ext) return null;

       const deltaX = newX - ext.x;
       const deltaY = newY - ext.y;

       // If vertical shift dominant or pure vertical:
       // Adjust vertical constant offset: f(x) + deltaY
       let rawFormula = (analysis.rawInput || analysis.formulaClean || analysis.formulaLatex || '')
           .replace(/^(?:y|f\(x\))\s*=\s*/i, '').trim();

       if (Math.abs(deltaY) >= 0.05) {
         // Check if formula already ends with an addition/subtraction of a constant: e.g. "sin(x)^2 + 1" or "- 3"
         const constantMatch = rawFormula.match(/\s*([+-])\s*(\d+(?:\.\d+)?)\s*$/);
         if (constantMatch) {
           const sign = constantMatch[1];
           const val = parseFloat(constantMatch[2]) * (sign === '-' ? -1 : 1);
           const newVal = val + deltaY;
           const prefix = rawFormula.substring(0, constantMatch.index).trim();
           if (Math.abs(newVal) < 1e-4) {
             rawFormula = prefix;
           } else {
             const newSign = newVal >= 0 ? '+' : '-';
             rawFormula = `${prefix} ${newSign} ${Math.abs(Number(newVal.toFixed(2)))}`;
           }
         } else {
           const newSign = deltaY >= 0 ? '+' : '-';
           rawFormula = `${rawFormula} ${newSign} ${Math.abs(Number(deltaY.toFixed(2)))}`;
         }
       }

       return rawFormula;
     }
   }
   ```

2. **Integration in `app.js` (`handleExtremumDrag`):**
   - Đảm bảo khi `computeFormulaFromDrag` trả về công thức mới thì `reactiveRender(newFormula)` được gọi để cập nhật tức thì đồ thị và các điểm CĐ/CT.
   - Thêm cờ chống loop sự kiện để drag mượt mà ở 60 FPS.

---

## Verification
- Chạy `node scripts/test_curve_manipulator.mjs` kiểm tra kéo cực trị $y = \sin(x)^2 + 1$ từ $y=2$ lên $y=3$ cho ra $\sin(x)^2 + 2$.

