# Brainstorm Report: Project Startup Error Resolution & StudioState Refactoring Strategy

**Date:** 2026-10-20  
**Context:** Khắc phục lỗi biên dịch khi khởi động `flutter run -d windows` và định hình lộ trình tái cấu trúc StudioState

---

## 1. Vấn Đề Gốc Rễ (Root Cause)
Khi khởi động Frontend bằng lệnh `flutter run -d windows`, quá trình build thất bại với **636 lỗi biên dịch**.
- **Nguyên nhân:** Trước đó có một phiên làm việc dở dang cố gắng bóc tách `StudioState` (God Object 3000 dòng) nhưng chưa hoàn tất:
  - 4 file `part of` (`studio_state_annotations.dart`, `studio_state_pdf.dart`, `studio_state_plugins.dart`, `studio_state_smart_pen.dart`) đã bị xóa khỏi working tree.
  - `studio_state.dart` vẫn giữ nguyên các chỉ thị `part` và lời gọi đến các method/class trong các file bị xóa.
  - Các Domain Controllers mới dự định thay thế trong `services/controllers/` chưa được cài đặt (thư mục rỗng).

---

## 2. Giải Pháp Đã Chọn (Hướng 3: Hybrid)
1. **Giai đoạn 1 (Unblock & Khôi phục ngay):**
   - Khôi phục nguyên vẹn 4 file `studio_state_*.dart` và hoàn trả `studio_state.dart` về trạng thái đồng bộ working tree.
   - Loại bỏ các file rác / dead code chưa dùng (`plugin_host_bridge.dart`).
   - Đảm bảo toàn bộ hệ sinh thái chạy được 100% không còn lỗi biên dịch.
2. **Giai đoạn 2 (Bóc tách có kiểm soát qua `/bb-plan`):**
   - Không bóc tách vội vàng làm gián đoạn việc chạy ứng dụng.
   - Sử dụng quy trình chuẩn `bb-plan` -> `bb-cook` với TDD & verification gates để tái cấu trúc `StudioState` sang các Domain Controller (`CanvasDrawingController`, `PdfSmartPenController`, `AudioSyncController`, `StudioPluginBridgeController`).

---

## 3. Kết Quả Kiểm Tra Xác Thực Sau Khi Khôi Phục

| Kiểm tra / Gate | Lệnh thực thi | Kết quả |
| :--- | :--- | :---: |
| **Flutter Linter / Analyzer** | `flutter analyze --no-fatal-infos` | **0 issues** (No issues found) |
| **Kiến Trúc CI (12 Invariants)** | `flutter test test/architecture_test.dart` | **12/12 Invariants Pass (100%)** |
| **Studio Board Test Suite** | `flutter test test/features/studio_board/` | **206/206 Tests Pass (100%)** |
| **Plugin Package Integrity** | `node scripts/validate_plugins.mjs` | **100% Đồng bộ Schema v2.1** |
| **Backend Spring Boot Tests** | `mvn test -f backend/api/pom.xml` | **129/129 Tests Pass (BUILD SUCCESS)** |

---

## 4. Các Bước Tiếp Theo
- Người dùng có thể khởi động và kiểm tra ứng dụng:
  - Khởi động backend: `cd backend/api && mvn spring-boot:run`
  - Khởi động frontend: `cd frontend && flutter run -d windows`
- Khi sẵn sàng bóc tách `StudioState` thành Domain Controllers: chạy lệnh `/bb-plan`.

