# Plan: Casio Calculator Subject Plugin Integration

**Date:** 2026-10-17  
**Mode:** --hard  
**Risk:** normal — Tích hợp plugin máy tính Casio độc lập vào hệ thống Microkernel Host, không can thiệp lõi Flutter, không sửa schema CSDL.  
**Brainstorm Reference:** `plans/reports/261017-casio-calculator-plugin-brainstorm.md`  

---

## 1. Executive Summary & Architecture Blueprint
Tích hợp repo máy tính khoa học cầm tay HocLuc ([nguyenquocan0101/HocLucCalculator](https://github.com/nguyenquocan0101/HocLucCalculator)) thành một Subject Plugin chuẩn mực cho HocLuc Teacher Station:
- **Kiến trúc Clean Microkernel**: Toàn bộ mã nguồn máy tính được build tĩnh và nằm độc lập tại `plugins/casio_calculator/`, tuân thủ nguyên tắc Zero Hardcoded Names trong `frontend/lib/`.
- **Pure Webview Plugin (`backend: null`)**: Chạy 100% bằng HTML/CSS/JS (React 19 bundle) trong WebView2, không tiêu tốn tiến trình nền hay cổng socket.
- **Floating Window UX**: Hiển thị dưới dạng cửa sổ nổi kéo thả tự do trên nền bảng phấn Studio (`placement: "floating_window"`).
- **Phân phối 1-Click & Offline Cache**: Đóng gói thành `plugins/casio_calculator.hlep` (~500KB), hỗ trợ giáo viên cài đặt 1-chạm từ Kho Tiện ích và sử dụng hoàn toàn offline.
- **Host Bridge & Ghim Bảng**: Hỗ trợ xuất biểu thức / kết quả tính toán trực tiếp lên bảng phấn qua `hocluc-plugin-sdk.js`.

---

## 2. Phases Overview & Story Coverage

| Phase | Title | Scope & Output Files |
| :--- | :--- | :--- |
| **Phase 01** | Plugin Scaffolding & Web Bundle Build | Nâng cấp `package_plugin.mjs` hỗ trợ tham số động; build `HocLucCalculator` với relative base path; tạo `plugins/casio_calculator/` với `manifest.json` v2, icon và `ui/` bundle. |
| **Phase 02** | Packaging `.hlep` & Marketplace Catalog | Đóng gói `casio_calculator.hlep`; cập nhật metadata catalog cho Plugin Marketplace; kiểm thử nạp plugin và giải nén vào `%LOCALAPPDATA%/HocLuc/plugins/`. |
| **Phase 03** | Board SDK Bridge & Architecture Verification | Kiểm tra tương tác mở cửa sổ nổi `floating_window` trên bảng phấn Studio, kiểm thử lệnh ghim biểu thức/kết quả lên bảng; chạy `flutter test test/architecture_test.dart` (khóa 5/5 bất biến). |
| **Phase 04** | Host Static Gateway & Neutral Floating Window | Xây dựng `PluginWebServer` (HttpServer loopback cổng động) phục vụ Webview chuẩn VS Code, zero CORS cho ES Modules; làm sạch thanh header của `FloatingPluginWindow`. |

---

## 3. Risks & Mitigations

1. **Rủi ro đường dẫn tuyệt đối trong Vite bundle**:
   *Nguyên nhân*: Vite mặc định build đường dẫn asset dạng `/assets/...` khiến Webview local file (`file:///`) hoặc custom host không nạp được file JS/CSS.
   *Giải pháp*: Cấu hình `base: './'` trong Vite config trước khi build để mọi đường dẫn asset là relative.
2. **Rủi ro tràn cửa sổ bảng phấn**:
   *Nguyên nhân*: Kích thước máy tính cố định có thể che khuất đề bài của giáo viên.
   *Giải pháp*: Cấu hình `default_width: 380`, `default_height: 640`, hỗ trợ kéo thả tự do (`floating_window`) và thu nhỏ góc màn hình.
3. **Rủi ro vi phạm kiến trúc Microkernel**:
   *Nguyên nhân*: Lập trình viên vô tình import hoặc hardcode ID `casio` vào `frontend/lib/`.
   *Giải pháp*: Toàn bộ danh mục nạp động qua `PluginManager` và manifest; kiểm chứng tự động bằng `test/architecture_test.dart`.

---

## Session Notes
<!-- Updated by cook automatically — do not edit manually -->

**Last active:** 2026-10-17 15:45  
**Phase in progress:** Phase 04 Completed  
**Status:** All Phases 01-04 Completed (26/26 tests passed; PluginWebServer loopback live; clean neutral floating window).

### Decisions made this session
- Triển khai `PluginWebServer` tích hợp trên loopback `127.0.0.1` với cổng động tự do, xóa bỏ triệt để rào cản CORS của Chromium WebView2 khi load React/Vite ES modules.
- Làm sạch thanh tiêu đề của `FloatingPluginWindow` và `PluginHostDrawer`, xóa bỏ hoàn toàn nút cứng môn học ("Quét đoạn văn"), chuyển thành Neutral Host Window.
- Thiết lập Content-Type và CORS `Access-Control-Allow-Origin: *` cho loopback nội bộ để hỗ trợ mọi framework SPA trong tương lai.
- Xác nhận kiểm thử kiến trúc 5/5 bất biến và toàn bộ test suite đạt 26/26 test PASSED.

### Next immediate action
Khởi động lại ứng dụng và trải nghiệm máy tính Casio trên màn hình bảng phấn Studio.
