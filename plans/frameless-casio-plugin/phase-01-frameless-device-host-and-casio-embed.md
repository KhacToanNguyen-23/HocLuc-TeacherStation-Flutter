# Phase 01: Frameless Floating Host & Casio Bare-Device CSS

## 1. Mục Tiêu
- Thêm trường `frameless` (`bool`, mặc định `false`) vào `PluginManifest` và `PluginCatalogItem`.
- Khi `plugin.manifest.frameless == true`, `FloatingPluginWindow` không vẽ thanh tiêu đề rời rạc hay viền hộp chữ nhật bên ngoài mà bo góc `24px` ôm sát thân thiết bị, đồng thời đặt thanh nắm kéo (`Drag Bezel`) và nút đóng `×` nhỏ gọn ngay trên gờ trên của thân máy.
- Trong `plugins/casio_calculator/ui/`, tạo `embed.css` và nhúng vào `index.html` để ẩn toàn bộ `.calculator-app-heading` (`hocluc.com`), `.calculator-copyright` (`© 2026 hocluc.com`), xóa bỏ nền trắng `#edf1f5` và đưa `.calc-face` tràn khít 100% khung cửa sổ (`328x556`).
- Đóng gói lại `plugins/casio_calculator.hlep` và cập nhật bài kiểm thử `casio_calculator_e2e_test.dart`.

