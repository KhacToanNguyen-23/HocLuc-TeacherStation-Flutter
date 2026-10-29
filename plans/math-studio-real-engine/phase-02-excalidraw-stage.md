# Phase 2: Stage — dựng scene Excalidraw (TDD, hàm thuần)

## Mục tiêu
Các hàm thuần (không DOM) chuyển dữ liệu từ engine thành element skeleton của Excalidraw, kiểm thử được trong Node. Giao diện vẽ là canvas Excalidraw; toolbar ẩn.

## File
- `src/stage/viewport.js`: world↔screen, zoom/pan, bước chia lưới "đẹp" (1-2-5).
- `src/stage/axes.js`: trục Oxy, mũi tên, vạch/nhãn; thuật toán tránh đè nhãn (hộp bao + dịch chuyển có thứ tự ưu tiên: trục < đường cong < điểm đặc biệt).
- `src/stage/curve.js`: một element `line` nhiều điểm cho mỗi đoạn liên tục; tách đoạn tại gián đoạn/tiệm cận; cắt theo viewport; tối đa vài trăm điểm/đoạn.
- `src/stage/markers.js`: cực trị, điểm uốn, giao điểm y=m, M, tiệm cận (nét đứt), nhãn.
- `src/stage/tangent.js`, `src/stage/riemann.js`: tiếp tuyến, cột chữ nhật theo n.
- `src/stage/solid3d.js`: chiếu 3D→2D quanh Ox; sinh các elip mặt cắt, đường sinh biên; **quy tắc hidden-line**: cung sau (khuất) nét đứt, cung trước nét liền; xoay theo (rotX, rotY).
- `engine/tests/stage.test.mjs`.

## Tests viết trước
- Curve: `(2x+1)/(x-1)` cho ≥ 2 đoạn tách tại x=1, không có đoạn nào nối qua tiệm cận; `ln(x)` không có điểm với x≤0.
- Axes: không có hai nhãn nào có hộp bao giao nhau (kiểm bằng hàm giao hộp) trên các mức zoom 14–160 px/đơn vị.
- Markers: `x^3-3x` có đúng 2 marker cực trị với toạ độ đúng; y=m=0 có 3 marker giao điểm.
- Tangent: tại x0=2 phương trình/độ dốc đúng 9.
- Riemann: số element cột = n với n∈{4,12,50}; chiều cao cột đúng với mode giữa.
- Solid3D: với góc quay 360°, mọi cung có z<0 (khuất) đặt `strokeStyle:'dashed'`, cung z≥0 `solid`; đổi (rotX, rotY) thì phân loại đổi đúng; số lượng element có trần (≤ 400) để giữ hiệu năng.
- Style: nét vẽ tay nhẹ (`roughness` thấp), không dùng font mặc định ngoài danh sách đã bundle.

## Tiêu chí hoàn thành
Test stage xanh; dựng scene mẫu cho 8 hàm không throw; trần số element được kiểm.

