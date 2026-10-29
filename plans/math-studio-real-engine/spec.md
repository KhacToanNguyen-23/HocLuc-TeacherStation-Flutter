# Spec: Math Studio — engine toán thật + canvas Excalidraw thật

**Date:** 2026-10-29
**Status:** Draft (còn 3 mục NEEDS CLARIFICATION cần plan giải bằng spike)
**Thay thế:** các phần "cook" của `plans/flexible-math-studio-refactor` đã bị đánh giá không đạt (UI tĩnh).

---

## Problem Statement
Plugin `math_studio` hiện chỉ là UI tĩnh: không dùng Excalidraw, không có engine toán thật (y' và nguyên hàm là bảng regex cố định), canvas không vẽ đồ thị, còn ~10 file tàn dư. Cần xây lại bằng thư viện mã nguồn mở (Excalidraw + math.js + CAS) để mọi chức năng đã chốt hoạt động thật, chạy offline, plugin tải từ Marketplace.

---

## Quyết định đã chốt
- congcutoanhoc: thuật toán nằm ở server PHP, không có giấy phép, không xin được phép → chỉ tham chiếu ý tưởng/hành vi; tự cài đặt. Cấm sao chép mã/UI/văn bản/tài nguyên và cấm gọi API của họ.
- Engine toán: math.js (Apache-2.0) + nerdamer (Apache-2.0, cần xác minh) + công thức giải tích chuẩn.
- Canvas: `@excalidraw/excalidraw` (MIT) bundle offline bằng esbuild (đã thử: build thành công, ~9MB JS, 141KB CSS). Ẩn toàn bộ thanh công cụ vẽ.
- Giữ nguyên 3 trang, bố cục 2 cột, nhập liệu gọn, ghim bảng đen, tách Oxyz thành plugin riêng.

---

## User Stories

- **[P1]** As a giáo viên, I want to nhập BẤT KỲ hàm số nào so that y', cực trị, tiệm cận, nguyên hàm, đồ thị đều tính từ chính biểu thức đó.
  Accepted when: với mỗi hàm trong bộ kiểm thử (xem Success Criteria), y' đúng symbolic, đường cong được vẽ trên canvas Excalidraw, và KHÔNG tồn tại bảng/regex tra cứu theo hàm cụ thể trong mã nguồn.

- **[P1]** As a giáo viên, I want to kéo điểm M trên đường cong và kéo đường y = m so that tiếp tuyến và số nghiệm cập nhật tức thì ở cả canvas lẫn bảng số liệu (2 chiều).
  Accepted when: kéo M đến x₀ thì hệ số góc hiển thị = f'(x₀) sai số < 1e-3; kéo y = m thì số nghiệm = đáp án chuẩn của bộ kiểm thử.

- **[P1]** As a giáo viên, I want trang Bảng biến thiên chuẩn SGK so that học sinh thấy x, y', y, dấu, mũi tên, ‖ tại điểm gián đoạn.
  Accepted when: BBT sinh từ chính hàm đang nhập (không mẫu cố định), đúng với bộ kiểm thử; có nút ghim riêng.

- **[P1]** As a giáo viên, I want trang Tích phân với thanh trượt số hình chữ nhật Riemann n∈[4,50] so that học sinh thấy tổng Riemann hội tụ về tích phân.
  Accepted when: số cột trên canvas = n; S_n hiển thị đúng; ở n=50 sai khác tích phân chính xác ≤ 1% cho các hàm kiểm thử.

- **[P1]** As a giáo viên, I want khối tròn xoay quanh Ox dựng trực tiếp từ đồ thị, nét liền (thấy) và nét đứt (khuất), xoay được đa góc so that học sinh quan sát mọi phía.
  Accepted when: y=√x trên [0,4] cho V = 8π (± 0.01); kéo chuột đổi góc nhìn và đường khuất chuyển nét đứt đúng quy tắc.

- **[P1]** As a giáo viên, I want "Ghim vào bảng" xuất ảnh từ chính canvas Excalidraw so that thẻ trên bảng đen có đồ thị thật và co giãn/xoay 8 điểm neo.
  Accepted when: chạy app thật, bấm ghim ở cả 3 trang → thẻ hiển thị đúng nội dung đồ thị/BBT (không trống).

- **[P1]** As a kỹ sư, I want xoá hết tàn dư và code tự viết sai hướng so that plugin chỉ chứa code đang dùng.
  Accepted when: không còn `graph_board.js`, `core/{math_cas,store,geometry_parser,integral_solver,rational}.js`, `export/board_exporter.js`, `render/{bbt_generator,math_keyboard}.js`, `vendor/jsxgraph/`, `vendor/rough.js` (Excalidraw đã gồm rough), và `math_engine.js` cũ; `frontend/lib/` vẫn không chứa logic/tên plugin toán.

- **[P2]** Phím tắt mẫu THPT (preset) — đã bỏ khỏi bố cục theo yêu cầu "bỏ cho gọn"; không làm.
- **[P3]** _(ngoài phạm vi)_ Oxyz (mặt phẳng, mặt cầu) — plugin riêng.

---

## Functional Requirements
1. FR-01: Bundle offline bằng esbuild (`conditions: ['production']`), kết quả đặt trong `plugins/math_studio/ui/` (JS + CSS + fonts), font vẽ tay Excalidraw copy local, KHÔNG tải CDN lúc chạy.
2. FR-02: `engine/` (JS thuần, chạy được trong Node để test): parse (math.js), đạo hàm symbolic, cực trị/điểm uốn (nghiệm y', y'' bằng phương pháp số có kiểm tra đổi dấu), tiệm cận đứng/ngang/xiên (giới hạn số + nghiệm mẫu), nguyên hàm (nerdamer; hàm không có biểu thức sơ cấp → hiển thị thông báo + tích phân số), tích phân số, tổng Riemann (trái/phải/giữa), thể tích tròn xoay.
3. FR-03: `stage/` dựng scene Excalidraw từ dữ liệu toán học: trục Oxy, vạch/nhãn không đè nhau, đường cong (một element `line` nhiều điểm, tách đoạn tại gián đoạn), tiệm cận nét đứt, điểm cực trị, tiếp tuyến, y=m, cột Riemann, khối tròn xoay (chiếu 3D→2D). Toolbar vẽ ẩn.
4. FR-04: M và y=m kéo được (cách thực hiện chốt bằng spike — xem NEEDS CLARIFICATION 1); thanh trượt ở bảng trái đồng bộ 2 chiều.
5. FR-05: BBT sinh từ kết quả engine, xuất SVG; ghim ảnh dùng API xuất của Excalidraw (PNG ≥ 2x cho đồ thị/tích phân/3D, SVG cho BBT) qua `window.HocLuc`.
6. FR-06: Xoá tàn dư theo story P1 cuối; cập nhật `math_studio.hlep` bằng `node scripts/package_plugin.mjs math_studio`.
7. FR-07: Bộ kiểm thử tự động cho `engine/` chạy bằng Node trong repo (nằm ngoài `frontend/lib`), có trong hướng dẫn chạy.

---

## Non-Functional Requirements
- Performance: đổi biểu thức → cập nhật scene ≤ 100 ms (hàm kiểm thử, màn 1080p); kéo M/y=m không rớt dưới 30 FPS. (Đo thật khi cook.)
- Offline: plugin mở được khi tắt mạng (kiểm bằng cách chặn mạng).
- Kích thước: đo và báo cáo kích thước JS bundle và `.hlep` sau nén; ngưỡng chốt trong plan (số đo thử nghiệm hiện tại: JS ≈ 9MB chưa tối ưu).
- Giấy phép: chỉ dùng thư viện MIT/Apache-2.0/MIT-tương đương; lưu NOTICE các giấy phép trong plugin.

---

## Success Criteria

Bộ hàm kiểm thử bắt buộc: `x^3-3x`, `2x^2-3x+1`, `(2x+1)/(x-1)`, `(x^2+x+1)/(x-1)`, `sin(x)`, `e^(-x^2)`, `sqrt(4-x^2)`, `ln(x)`.
- [ ] 8/8 hàm: y' đúng (so với đạo hàm chuẩn tại ≥ 5 điểm, sai số < 1e-6) và tự thay đổi khi đổi hàm (ảnh lỗi cũ không tái diễn: nhập 2x^2-3x+1 → y' = 4x-3).
- [ ] Cực trị, tiệm cận, số nghiệm y=m khớp đáp án chuẩn cho từng hàm có liên quan (x^3-3x: cực đại (-1;2), cực tiểu (1;-2); (2x+1)/(x-1): TCĐ x=1, TCN y=2).
- [ ] Riemann n=50 sai ≤ 1% so với tích phân chính xác; V(√x,[0,4]) = 8π ± 0.01.
- [ ] Canvas hiển thị đường cong thật, kéo M và y=m hoạt động, không có chữ đè nhau (kiểm bằng ảnh chụp thực tế).
- [ ] Ghim bảng từ 3 trang đều ra thẻ có nội dung (chạy app thật, có ảnh chụp).
- [ ] Mở plugin khi tắt mạng thành công.
- [ ] Không còn file tàn dư liệt kê; `node scripts/validate_plugins.mjs`, `flutter test test/architecture_test.dart` (12/12), `dart analyze` đều qua.
- [ ] Báo cáo hoàn thành liệt kê rõ phần nào ĐÃ chạy thật và phần nào CHƯA kiểm chứng.

---

## Out of Scope
- Sao chép mã/giao diện/văn bản/tài nguyên của congcutoanhoc; gọi API của họ.
- Nhúng GeoGebra.
- Vẽ tay chú thích (đã chốt "không cần").
- Hình học không gian Oxyz.

---

## Assumptions
- WebView2 chạy được bundle Excalidraw (cần xác nhận trong spike đầu tiên).
- nerdamer (Apache-2.0) đủ phủ hàm phổ thông; nếu không, nguyên hàm tổng quát chỉ hỗ trợ lớp hàm nhỏ và phần còn lại dùng tích phân số.

---

## [NEEDS CLARIFICATION]
- [ ] Cách kéo M / y=m khi ẩn toolbar: (a) edit mode + khóa element khác + ẩn UI; (b) viewMode + overlay pointer + `updateScene`. (Spike.)
- [ ] Ngưỡng kích thước bundle/`.hlep` chấp nhận được và cách tối ưu (ESM split, tree-shake mathjs).
- [ ] Cách kiểm thử UI tự động trong WebView2 (smoke test) ngoài test engine bằng Node.

