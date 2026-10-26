# Phase 2: Nhãn Tọa Độ & Huy Hiệu Công Thức Cập Nhật Thời Gian Thực

## Goal
Cập nhật nhãn điểm cực trị và huy hiệu công thức góc trái theo thời gian thực khi đang kéo cực trị.

## Requirements
1. Trong `graph_plotter.js`:
   - Nhãn điểm cực trị:
     ```javascript
     name: '',
     withLabel: false
     ```
     Kèm theo text element reactive:
     ```javascript
     board.create('text', [
       () => extPt.X(),
       () => isCT ? extPt.Y() - 0.45 : extPt.Y() + 0.45,
       () => `${ext.type} (${Number(extPt.X().toFixed(1))}; ${Number(extPt.Y().toFixed(1))})`
     ], {
       anchorX: 'middle',
       anchorY: isCT ? 'top' : 'bottom',
       strokeColor: colors.extremumDot,
       fontSize: 11,
       fontWeight: 'bold',
       fixed: true
     });
     ```
   - Thẻ huy hiệu công thức góc trái:
     ```javascript
     board.create('text', [
       () => board.getBoundingBox()[0] + 0.04 * (board.getBoundingBox()[2] - board.getBoundingBox()[0]),
       () => board.getBoundingBox()[1] - 0.08 * (board.getBoundingBox()[1] - board.getBoundingBox()[3]),
       () => {
         const formula = options.getFormula ? options.getFormula() : (analysis.rawInput || 'f(x)');
         return `<div style="background: rgba(255,255,255,0.92); border: 1px solid #d6e3f2; border-radius: 6px; padding: 2px 8px; font-family: 'Cambria Math', serif; font-style: italic; font-weight: bold; font-size: 13px; color: ${colors.curve}; box-shadow: 0 1px 3px rgba(0,0,0,0.06); pointer-events: none;">y = ${formula.replace(/\^([0-9a-zA-Z]+)/g, '<sup>$1</sup>')}</div>`;
       }
     ], { fixed: true, highlight: false });
     ```
2. Trong `app.js`:
   - Cung cấp `getFormula: () => mathInput.value`.
   - Cập nhật `extremaEditorContainer` khi kéo.

## Success Criteria
- Nhãn điểm hiển thị chính xác tọa độ con trỏ chuột trong lúc kéo.
- Huy hiệu công thức góc trái tự động cập nhật công thức mới.

