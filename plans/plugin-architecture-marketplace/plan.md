# Plan: Plugin Architecture Refactoring & Cloud Marketplace

**Date:** 2026-10-15  
**Mode:** --hard  
**Risk:** high-risk — Tái cấu trúc phân tầng kiến trúc plugin, can thiệp vào quản lý tiến trình hệ điều hành (Process.start), lưu trữ tệp tin (%LOCALAPPDATA%) và IPC giữa Flutter Core và Webview.  
**Spec Reference:** `plans/plugin-architecture-marketplace/spec.md`  

---

## 1. Executive Summary & Architecture Blueprint
Mục tiêu là xóa bỏ hoàn toàn trạng thái "code chắp vá / tới đâu dùng tới đó" của hệ thống Plugin hiện tại, thiết lập một kiến trúc **Microkernel Host thuần khiết** trong Flutter Desktop:
- Không còn bất kỳ chuỗi tên plugin nào được hardcode trong `frontend/lib/`.
- Quản lý bộ nhớ tối ưu: Không nạp file vào RAM khi chưa dùng, nạp On-Demand khi mở và dọn sạch khi đóng.
- Cấp phát cổng mạng ngẫu nhiên (Dynamic Port) và quản lý tiến trình an toàn qua `ProcessSupervisor`.
- Giao tiếp chuẩn hóa giữa Webview và bảng phấn thông qua `hocluc-plugin-sdk.js` và `HostBridge`.

---

## 2. Phases Overview & Story Coverage

| Phase | Title | Stories Covered | Output Files |
| :--- | :--- | :--- | :--- |
| **Phase 01** | Contract & Plugin SDK Layer | Developer Story (P1), FR-01, FR-04 | `hocluc-plugin-sdk.js`, `manifest.json` v2, update `english_assistant` |
| **Phase 02** | Process Supervisor & Host Bridge | Lifecycle Story (P1), FR-03, FR-04 | `process_supervisor.dart`, `host_bridge.dart` |
| **Phase 03** | Storage Manager & Clean Microkernel | Download Story (P1), FR-02, FR-05 | `plugin_storage_manager.dart`, refactor `plugin_manager.dart`, `flat_host_native.dart` |
| **Phase 04** | Architecture Tests & Verification | Quality Criteria, Uninstall Story (P2) | `test/architecture_test.dart`, golden package `.hlep` v2 |

---

## 3. Risks & Mitigations

1. **Rủi ro Zombie Process trên Windows**: Tiến trình Python bị treo nếu Flutter app crash đột ngột.  
   *Giải pháp*: `ProcessSupervisor` triển khai cơ chế Heartbeat ping song công (bi-directional health check). Nếu sau 5 giây không nhận được ping từ Flutter Host, tiến trình Python tự động tắt.
2. **Rủi ro Xung đột Port mạng**:  
   *Giải pháp*: Sử dụng `ServerSocket.bind(InternetAddress.loopbackIPv4, 0)` để hệ điều hành Windows cấp phát cổng ngẫu nhiên khả dụng, sau đó đóng socket và truyền cổng đó vào argument `--port` của tiến trình con.
3. **Rủi ro Phá vỡ tính năng hiện tại của Studio Bảng phấn**:  
   *Giải pháp*: Giữ nguyên giao diện người dùng bên ngoài, chỉ refactor tầng dữ liệu và cầu nối bên dưới; chuyển đổi tương thích ngược (backward compatibility) trong quá trình di chuyển.

---

## Session Notes
<!-- Updated by cook automatically — do not edit manually -->

**Last active:** 2026-10-15 15:45
**Phase in progress:** Completed
**Status:** All Phases 01-04 Completed (All unit, storage, supervisor, architecture, and E2E tests passed).

### Decisions made this session
- Xây dựng `PluginStorageManager` quản lý giải nén `.hlep` ra thư mục người dùng `%LOCALAPPDATA%/HocLuc/plugins/<id>/v<version>/` (hoặc macOS/Linux equivalent), hỗ trợ quét tự động và dọn sạch ổ đĩa khi gỡ cài đặt.
- Refactor `PluginManager` thành Pure Microkernel Registry: Thay thế `filesMap` byte in-memory bằng `installDirectory` trên ổ đĩa, xóa bỏ toàn bộ mock string HTML/JS/CSS, tự động gắn kết vòng đời sidecar (`startSidecar` khi open, `stopSidecar` khi close/uninstall).
- Refactor `FlatHost` loại bỏ toàn bộ các chuỗi hardcode tên riêng của plugin (`File('../plugins/english_assistant/...')`), nạp file an toàn qua dynamic port query parameter.
- Xây dựng hệ thống phòng vệ kiến trúc tự động `test/architecture_test.dart` (khóa cứng 5 bất biến: không hardcode tên plugin, không cố định cổng 18888, không import chéo, schema v2, và phân bổ cổng động).
- Đóng gói Golden Sample `plugins/english_assistant.hlep` (Schema v2) và kiểm thử thông qua 4/4 kịch bản E2E trong `english_assistant_e2e_test.dart`.

### Next immediate action
Báo cáo kết quả kiểm thử toàn diện cho người dùng, chuẩn bị commit Git theo chuẩn conventional commit.

