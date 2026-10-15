# Spec: Plugin Architecture Refactoring & Cloud Marketplace

**Date:** 2026-10-15  
**Status:** Ready  

---

## Problem Statement
Kiến trúc plugin hiện tại đang mang tính chất đối phó/chắp vá (ad-hoc), hardcode trực tiếp các đường dẫn và logic của plugin Tiếng Anh vào nhân Flutter Core, lưu trữ toàn bộ dữ liệu file thô trong RAM và ép máy giáo viên phải chứa sẵn file plugin. Hệ thống cần được tái cấu trúc theo mô hình Microkernel hướng đối tượng chuẩn (OOP/SOLID), hỗ trợ Cloud Marketplace để giáo viên cài đặt theo nhu cầu (On-Demand), nạp vào RAM khi dùng và giải phóng khi đóng, đồng thời cung cấp bộ quy chuẩn & SDK để các lập trình viên khác phát triển plugin độc lập.

---

## User Stories

<!-- P1 = MVP (must ship), P2 = nice-to-have, P3 = future/out-of-scope -->

- **[P1]** Là một giáo viên, tôi muốn mở giao diện Kho Plugin (Marketplace) từ thanh công cụ/drawer để xem danh sách các công cụ bổ trợ cho môn học của mình.  
  *Accepted when:* Danh sách plugin hiển thị đầy đủ icon, tên, mô tả, phiên bản và trạng thái (Chưa cài đặt / Đã cài đặt / Có bản cập nhật mới).

- **[P1]** Là một giáo viên, tôi muốn nhấn "Tải về" một plugin trên Marketplace để ứng dụng tự động cài đặt và sẵn sàng sử dụng mà không cần cấu hình thêm bất kỳ phần mềm nào khác.  
  *Accepted when:* Ứng dụng tải gói `.hlep` từ Cloud, giải nén vào thư mục an toàn của người dùng (`%LOCALAPPDATA%/HocLuc/plugins/<id>`), và tự động chuyển trạng thái thành "Đã cài đặt" với thanh tiến độ rõ ràng.

- **[P1]** Là một giáo viên, tôi muốn khi mở một plugin thì plugin đó mới tiêu tốn RAM, và khi đóng lại thì RAM cùng các tiến trình nền liên quan phải được giải phóng hoàn toàn.  
  *Accepted when:* Đóng cửa sổ/drawer plugin thì WebView bị hủy và tiến trình sidecar (nếu có) được tắt hoàn toàn, bộ nhớ RAM được hoàn trả cho hệ điều hành.

- **[P1]** Là một lập trình viên (Developer), tôi muốn xây dựng một plugin mới (như Toán, Lý, Hóa) theo một bộ khung chuẩn (Manifest Schema + Plugin SDK) mà không phải sửa bất kỳ dòng code nào trong mã nguồn Flutter Core.  
  *Accepted when:* Thêm một plugin mới hoàn toàn độc lập, không cần import hay thêm logic điều kiện `if (pluginId == '...')` trong Flutter Core.

- **[P2]** Là một giáo viên, tôi muốn gỡ cài đặt (Uninstall) một plugin bất cứ lúc nào để giải phóng dung lượng ổ cứng cho những môn tôi không còn dạy.  
  *Accepted when:* Nhấn "Gỡ cài đặt" xóa sạch thư mục cache của plugin đó trên ổ đĩa và cập nhật trạng thái UI.

- **[P3]** _(Out of scope cho giai đoạn này)_: Chữ ký số mã hóa bảo mật cấp doanh nghiệp (Cryptographic signature verification), Thanh toán in-app mua plugin trả phí.

---

## Functional Requirements

1. **FR-01 (Manifest Schema v2)**: Định nghĩa cấu trúc `manifest.json` chuẩn hóa (ID, tên, icon, placement, UI entry, permissions, sidecar engine definition). Bất kỳ plugin nào thiếu trường bắt buộc sẽ bị từ chối kích hoạt.
2. **FR-02 (PluginStorageManager)**: Lớp dịch vụ chịu trách nhiệm tải tệp `.hlep` từ URL/Cloud, kiểm tra checksum, giải nén ra thư mục `%LOCALAPPDATA%/HocLuc/plugins/{id}/v{version}/`, và dọn dẹp các phiên bản cũ khi gỡ cài đặt.
3. **FR-03 (ProcessSupervisor)**: Lớp quản lý vòng đời tiến trình Sidecar (Python/Binary). Tự động cấp phát cổng động (Random available localhost port), kiểm tra health check endpoint, và đăng ký cơ chế tắt tiến trình triệt để (Windows Process Termination / Job Object).
4. **FR-04 (HostBridge & Typed RPC SDK)**: Cung cấp file thư viện JavaScript chuẩn (`hocluc-plugin-sdk.js`) cho giao diện Webview. Giao tiếp giữa Webview và Flutter Host thông qua giao thức Typed RPC `{ action, payload, requestId }` cho các quyền: chèn ghi chú lên bảng (`board:insert_annotation`), đọc văn bản đã chọn (`board:read_text`), và lưu trữ cục bộ (`storage:get/set`).
5. **FR-05 (Marketplace UI)**: Giao diện Drawer/Panel hiển thị danh mục plugin từ Remote API/JSON catalog, hỗ trợ tìm kiếm theo môn học, nút 1-click Download với Progress Bar, nút Cập nhật (khi version mới > version hiện tại) và nút Gỡ cài đặt.
6. **FR-06 (Refactor English Assistant)**: Tái cấu trúc plugin mẫu `english_assistant` theo chuẩn v2 mới, loại bỏ toàn bộ hardcode trong `frontend/lib/services/dgnl_service.dart`, `flat_host_native.dart` và `plugin_manager.dart`.

---

## Non-Functional Requirements

- **Performance**: 
  - Khởi động ứng dụng Flutter Core: Tăng thời gian khởi động không quá 50ms khi có 20 plugin đã cài đặt (chỉ đọc metadata JSON).
  - Mở giao diện plugin đã cài đặt trong vòng ≤ 800ms trên môi trường Windows Desktop thông thường.
  - Sau khi đóng plugin: 100% tài nguyên tiến trình con (sidecar process) phải bị terminate trong vòng ≤ 500ms.
- **Resource Footprint**:
  - Khi chưa mở plugin: Dung lượng RAM tiêu thụ thêm của hệ thống plugin là 0 MB (ngoại trừ danh sách đối tượng metadata vài KB).
- **Security & Sandboxing**:
  - Webview chỉ được phép gọi các API đã được khai báo tường minh trong mảng `permissions` của `manifest.json`.

---

## Success Criteria

- [ ] **Zero Hardcoded Names**: Trong toàn bộ thư mục `frontend/lib`, không còn bất kỳ dòng code nào chứa chuỗi `'english_assistant'`, `'dgnl'` hay port cứng `18888`.
- [ ] **1-Click Download & Run**: Giáo viên mở Marketplace, bấm "Tải về" một plugin mới -> Tải thành công -> Mở giao diện chạy trơn tru mà không cần can thiệp thủ công vào filesystem hay terminal.
- [ ] **Clean Lifecycle**: Kiểm tra Task Manager sau khi đóng plugin: Không còn tiến trình Python hoặc Webview treo ngầm.
- [ ] **Developer Golden Template**: Cung cấp tài liệu hướng dẫn và mã nguồn mẫu của `english_assistant` theo chuẩn mới, cho phép một dev bất kỳ tạo plugin mới chỉ bằng cách sao chép template và viết manifest.

---

## Out of Scope

- Marketplace cho phép người dùng bên thứ ba tùy ý tải plugin lên công khai (chưa có Developer Console công khai).
- Hỗ trợ plugin native viết bằng C++ / Rust dynamic library (DLL) trực tiếp vào Flutter engine (hiện tại chuẩn hóa qua Webview + Local Sidecar Process).

---

## Assumptions

- Ứng dụng Desktop chạy trên hệ điều hành Windows 10/11 (có sẵn WebView2 Runtime) và macOS.
- Thiết bị của giáo viên có dung lượng ổ đĩa trống tối thiểu 500MB cho phân vùng người dùng `%LOCALAPPDATA%`.
- Kết nối Internet khả dụng trong thời điểm giáo viên bấm tải hoặc cập nhật plugin từ Marketplace.

---

## [NEEDS CLARIFICATION]

*(Đã làm rõ xong ở phiên Brainstorm)*
