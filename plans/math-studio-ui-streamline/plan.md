# Plan: Tinh gọn Bố cục Math Studio (Hướng 2: Accordion Nâng Cao)

**Mode:** Fast  
**Risk:** normal — Tái cấu trúc bố cục HTML/CSS cho plugin math_studio (không đổi schema hay backend)  
**Spec:** `plans/math-studio-ui-streamline/spec.md`  
**Date:** 2026-10-26  

---

## Architecture & Layout Strategy
- **Core Viewport**: Giữ cột trái hiển thị trực diện 2 thẻ quan trọng nhất cho 90% nhu cầu giảng dạy:
  1. `Thẻ HÀM SỐ`: Chọn màu swatch, tiền tố $y=$, ô nhập công thức, nút xóa, nút Giới hạn $[a, b]$.
  2. `Thẻ ĐIỂM`: Nút chính `+ Thêm điểm`, các nút `Giao Ox`, `Giao Oy`, `Cực trị` (và hàng nhập số CĐ/CT khi kích hoạt).
- **Accordion "Tùy chọn nâng cao ▾"**:
  - Đặt dưới chân Thẻ ĐIỂM.
  - Thu gọn mặc định (`collapsed`).
  - Chứa 3 mục phụ:
    - `Vật thể tròn xoay quanh Ox` (toggle switch / button đồng bộ SGK 12).
    - `Khung nhìn thủ công` (thiết kế lại dạng lưới grid 2 cột `vp-grid-2col`, triệt tiêu 100% thanh cuộn ngang).
    - `Miền nghiệm (Hệ BPT)` (link placeholder).
- **Header Tabs Navigation**:
  - Căn chỉnh padding và font chữ của 4 tab (`Đồ thị`, `Bảng biến thiên`, `Hình 3D SGK`, `Tích phân`) để vừa khít mép phải thanh Header ở mọi độ phân giải chuẩn.

---

## Phases

- [x] **Phase 1: Tái cấu trúc HTML & Bổ sung Accordion "Tùy chọn nâng cao"**
  - File: `plugins/math_studio/ui/index.html`
  - Đưa 2 thẻ HÀM SỐ và ĐIỂM ra ngoài.
  - Đóng gói VẬT THỂ TRÒN XOAY, KHUNG NHÌN, MIỀN NGHIỆM vào khối `#advancedAccordion`.
  - Thiết kế lại lưới Khung nhìn dạng 2 cột co giãn `vp-grid-2col`.

- [x] **Phase 2: Thiết kế CSS, Triệt tiêu Thanh Cuộn & Cân đối Header**
  - File: `plugins/math_studio/ui/style.css`
  - Thêm CSS cho `.advanced-accordion-card`, `.accordion-header`, `.accordion-arrow`, `.accordion-body`.
  - Khóa chặt `overflow-x: hidden` ở `.left-controls-col` và `.control-card`.
  - Tối ưu kích thước `.mode-tab` để vừa vặn 100% trên Header.

- [x] **Phase 3: Kết nối Sự kiện JS, Đóng gói .hlep & Kiểm thử Hoàn thiện**
  - File: `plugins/math_studio/ui/app.js`
  - Bắt sự kiện click vào `#btnToggleAdvanced` để toggle class `open` / `hidden`.
  - Kiểm tra trạng thái quay quanh Ox của mô hình 2.5D khi toggle bên trong accordion.
  - Chạy validator: `node scripts/validate_plugins.mjs --fix`.
  - Chạy kiến trúc: `node scripts/run_architecture_check.mjs` (đảm bảo 12/12 Invariants PASS).

## Session Notes
<!-- Updated by cook automatically — do not edit manually -->

**Last active:** 2026-10-26 07:41
**Status:** All 3 phases completed successfully.
- P1 & P2 stories 100% covered.
- 0 horizontal scrollbar.
- Math Studio UI streamlined cleanly with Accordion.

