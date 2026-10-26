# Phase 1: Khử Mờ Trục Tọa Độ & Loại Bỏ Vạch Li Ti (Crisp SGK Axes)

## Goal
Loại bỏ hoàn toàn các vạch phụ li ti gây mờ trục $Ox, Oy$ và nâng cấp font chữ số lên 12px đậm nét, chuẩn SGK.

## Requirements
1. Trong `graph_plotter.js`:
   - Thiết lập cấu hình ticks cho trục $Ox$ và $Oy$:
     ```javascript
     ticks: {
       ticksDistance: sX,
       minorTicks: 0,
       insertTicks: false,
       strokeColor: colors.axis,
       strokeWidth: 1.2,
       majorHeight: 6,
       drawZero: false,
       drawLabels: true,
       label: {
         color: colors.axisLabel,
         fontSize: 12,
         fontWeight: '600',
         offset: [-4, -13],
         cssClass: 'sgk-tick-label'
       }
     }
     ```
   - Ẩn hoàn toàn nhãn `\int = ...` trên phần tử tích phân: `withLabel: false`.
2. Trong `style.css`:
   - Bổ sung CSS cho `.sgk-tick-label`, `.jxgbox text`, `.JXGtext`:
     - `text-rendering: optimizeLegibility;`
     - `-webkit-font-smoothing: antialiased;`
     - `font-weight: 600 !important;`

## Success Criteria
- Trục $Ox, Oy$ không còn các vạch răng lược li ti.
- Chữ số trên trục hiển thị rõ ràng, đậm nét, không bị mờ nhạt.
- Nhãn $\int = \text{số}$ có dấu không còn xuất hiện trên đồ thị.

