# Brainstorm Report: Math Studio Architectural & CAS Refactor

**Date:** 2026-10-26  
**Status:** Completed & Aligned with User  
**Spec Document:** [`plans/math-studio-cas-refactor/spec.md`](spec.md)  

---

## 1. Bối Cảnh & Vấn Đề (Context & Motivation)

Qua kiểm tra toàn diện mã nguồn và trải nghiệm người dùng của `plugins/math_studio`, đã phát hiện 5 vấn đề kiến trúc cốt lõi:
1. **Hardcode công thức giải tích:** Code cũ chỉ hỗ trợ vài mẫu đa thức/phân thức SGK cơ bản (bậc 3, bậc 4, trùng phương, 1/1, 2/1). Khi người dùng nhập các hàm bậc cao ($x^5, x^7$), lượng giác phức tạp ($\sin^2(x) + 1$), hoặc hàm mũ/căn thức, hệ thống thiếu điểm cực trị hoặc xử lý bất nhất.
2. **"God Object" `app.js` (979 dòng):** Quản lý 15 biến trạng thái toàn cục, 35 DOM queries, trực tiếp nối đuôi các hàm render thủ công.
3. **Phân mảnh động cơ Toán học:** Tồn tại 3 bộ giải song song (`calculus_solver.js`, `integral_solver.js`, `math_cas.js`) gây xung đột và trùng lặp logic.
4. **Tồn tại 2 đường ống render Đồ thị:** File `graph_plotter.js` vẫn giữ hàm sinh SVG nối chuỗi thủ công ~350 dòng gây lệch WYSIWYG so với bản JSXGraph trực tiếp.
5. **Đồ họa 3D tự chế hạn chế:** File `geometry_3d_engine.js` tự tính ma trận xoay SVG thay vì tận dụng module `View3D` sẵn có của thư viện JSXGraph.

---

## 2. Các Quyết Định Thiết Kế Đã Thống Nhất (Agreed Decisions)

Sau khi trao đổi và thống nhất với người dùng:

1. **Tích hợp Thư viện CAS chuyên nghiệp `Nerdamer` (~200KB thuần JS, offline 100%):**
   - Giải quyết triệt để vấn đề giải tích tổng quát: Tự động tính đạo hàm ký hiệu $y'$ và hiển thị trực tiếp cho giáo viên.
   - Tìm nghiệm, cực trị, tiệm cận chính xác cho MỌI hàm số thực mà không cần bất kỳ mẫu hardcode nào.
2. **Triệt tiêu God Object — Xây dựng `Store` tập trung (Single Source of Truth):**
   - Quản lý toàn bộ State qua Action/Dispatch và Subscribers.
   - Phân rã `app.js` xuống dưới 300 dòng. Mọi file trong plugin đều $\le 350-400$ dòng.
3. **Thống nhất 1 pipeline hiển thị & xuất đồ thị duy nhất:**
   - Dùng JSXGraph trên DOM `#graphContainer`.
   - Xuất lên bảng phấn bằng `board_exporter.js` serialize trực tiếp node SVG của DOM JSXGraph. Xóa sổ hoàn toàn code sinh SVG thủ công cũ.
4. **Phạm vi Hình học 3D (Hướng A):**
   - Chuyển đổi các mô hình 3D SGK sang sử dụng **JSXGraph View3D**, hỗ trợ xoay chuột 3D trực quan, tận dụng thư viện có sẵn mà không làm tăng dung lượng plugin.

---

## 3. Phân Tích Rủi Ro & Biện Pháp Phòng Ngừa

| Rủi ro | Mức độ | Biện pháp phòng ngừa |
| :--- | :---: | :--- |
| **Kích thước gói `.hlep` tăng do nhúng thư viện mới** | Thấp | `Nerdamer` chỉ nặng ~200KB (bản bundle core + calculus), nhỏ hơn rất nhiều so với JSXGraph (920KB) và hoàn toàn offline trong sandbox của plugin. |
| **Xung đột khi rút gọn `app.js`** | Trung bình | Xây dựng `core/store.js` trước, kiểm thử luồng State bằng các bài test tự động Node.js độc lập trước khi gắn vào DOM. |
| **Hàm số quá phức tạp không giải ra nghiệm chữ** | Thấp | Cơ chế CAS Hybrid: Ưu tiên giải nghiệm ký hiệu bằng Nerdamer; nếu hàm không có nghiệm giải tích dạng đóng (transcendental equations), hệ thống tự động fallback sang thuật toán số học lai Bisection + Newton-Raphson độ chính xác cao. |

---

## 4. Lộ Trình Triển Khai Tiếp Theo

Theo quy trình phát triển:
1. **Lập Kế Hoạch Thực Thi (`$bb-plan`):**
   - Chia thành các Phase cụ thể (Phase 1: Nerdamer CAS Engine, Phase 2: State Store & Modularization, Phase 3: JSXGraph View3D, Phase 4: UI Refinement & Full Verification Gate).
2. **Triển Khai Mã Nguồn (`$bb-cook`):**
   - Thực thi từng phase, kiểm thử đơn vị và bảo đảm 12/12 Invariants của `AGENTS.md` luôn đạt 100%.

