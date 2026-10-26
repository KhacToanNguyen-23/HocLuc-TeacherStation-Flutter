# Phase 2: State-Driven Central Store (`store.js`) & Rút Gọn `app.js`

## Context & Objectives
Xóa bỏ hoàn toàn "God Object" `app.js` (979 dòng) và 15 biến trạng thái toàn cục phân tán bằng một `Store` trung tâm tuân theo kiến trúc Single Source of Truth (Action-Reducer-Subscriber).

## Scope of Work
1. Tạo module `plugins/math_studio/ui/core/store.js`:
   - State schema:
     ```js
     {
       formula: 'x^3 - 3*x',
       derFormulaLatex: "y' = 3x^2 - 3",
       analysis: null,
       integral: null,
       activeView: 'graph', // 'graph' | 'bbt' | 'geometry3d' | 'integral'
       bounds: { xMin: -6, xMax: 6, yMin: -4.1, yMax: 4.1 },
       tickSteps: { stepX: 2, stepY: 2 },
       markedPoints: [],
       showExtrema: true,
       showOxIntercept: false,
       showOyIntercept: false,
       editingStickerId: null
     }
     ```
   - Dispatcher:
     - `SET_FORMULA`: Tính lại analysis, $y'$, integral, thông báo subscribers.
     - `SET_VIEW`: Đổi tab đang xem.
     - `SET_BOUNDS`: Cập nhật khung nhìn viewport.
     - `UPDATE_DRAG_EXTREMUM`: Kích hoạt nghịch đảo giải tích và cập nhật công thức.
     - `UPDATE_INTEGRAL_BOUNDS`: Kéo mút cận tích phân $a, b$.
     - `TOGGLE_POINT_MARK`: Bật tắt Cực trị, Giao Ox, Oy.
2. Tái cấu trúc `plugins/math_studio/ui/app.js`:
   - Loại bỏ toàn bộ biến toàn cục `let currentAnalysis, activeView, customBounds...`.
   - Kết nối UI listeners vào `store.dispatch(action)`.
   - Đăng ký `store.subscribe(state => ...)` để render giao diện tự động.
   - Giảm dung lượng `app.js` từ 979 dòng xuống dưới 250 dòng.

## Verification Commands
- `node scripts/test_app_logic.mjs` (Pass 100%).
- Kiểm tra số dòng code của `app.js` $\le 250$ dòng.

