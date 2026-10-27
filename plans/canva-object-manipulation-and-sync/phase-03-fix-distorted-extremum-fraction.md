# Phase 3: Fix Distorted Extremum Fraction in Math Studio Engine

## 1. Goal
Loại bỏ hoàn toàn lỗi hiển thị chuỗi phân số dài dị thường `(100000000000000/49999999999999; -2.70)` trên nhãn cực trị đồ thị.

## 2. Changes
- `plugins/math_studio/ui/core/calculus_solver.js`:
  - Trong `solveQuadraticPoly`:
    ```javascript
    const vxRaw = -b / (2 * a);
    const vx = Math.round(vxRaw * 10000) / 10000;
    const vyRaw = f(vx);
    const vy = Math.round(vyRaw * 10000) / 10000;
    const vxFrac = Number.isInteger(vx) ? `${vx}` : new Fraction(Math.round(-b * 100), Math.round(2 * a * 100)).toDisplayString();
    const vyStr = Number.isInteger(vy) ? `${vy}` : vy.toFixed(2);
    ```
- Chạy `node scripts/validate_plugins.mjs --fix` để đóng gói lại `plugins/math_studio.hlep`.

