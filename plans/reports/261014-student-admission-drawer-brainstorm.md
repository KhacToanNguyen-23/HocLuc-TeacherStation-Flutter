# Brainstorm: In-App Student Admission (Drawer & Banner Integration)

**Date:** 2026-10-14

## Context & Evidence
- Người dùng đã xác minh qua Google Meet trên trình duyệt: Tài khoản giáo viên `Nguyễn Khắc Toàn` đã ở trong cuộc gọi `meet.google.com/phz-xarf-iey` thành công.
- Google Meet xác nhận có học sinh đang chờ: *"Những người khác đang chờ. Hãy tham gia để cho họ vào."*
- Phía học sinh (Chrome): Hiện màn hình *"Vui lòng đợi cho đến khi người tổ chức cuộc họp đưa bạn vào cuộc gọi"*.
- Phía Teacher Station (Flutter): Drawer "Người tham gia" và Canvas chưa hiển thị khu vực duyệt học sinh.

## Root Causes Identified
1. **Lỗi `offsetParent === null` theo chuẩn W3C CSSOM:**
   - Toast duyệt của Google Meet là popup snackbar nổi dùng CSS `position: fixed`.
   - Theo chuẩn W3C CSSOM, mọi phần tử có `position: fixed` đều có `offsetParent === null`.
   - Mã `meet_bridge_script.dart` kiểm tra `if (b.offsetParent === null) return false;` khiến toàn bộ nút duyệt trong popup `position: fixed` bị loại bỏ.
2. **Thẻ phần tử trong Google Meet:**
   - Google Meet sử dụng kết hợp cả thẻ `<button>` và `<div role="button">`, `<span role="button">`. Selector hiện tại chỉ tìm `button`.
3. **Thiếu khu vực "Đang chờ duyệt" trong Drawer "Người tham gia":**
   - Drawer bên phải (`StudioStudentsDrawer`) chỉ hiển thị học sinh đã vào, chưa có khối danh sách chờ duyệt (Waiting Room).

## Ideas Explored
1. **Hướng 1 (Được chọn): Tích hợp trực tiếp vào Drawer "Người tham gia" + Toast Banner trên Bảng vẽ:**
   - Drawer bên phải thêm khối nổi bật màu xanh/vàng ở trên cùng: "Đang chờ duyệt ($count học sinh)" kèm nút `[Cho vào]` / `[Từ chối]` / `[Cho vào tất cả]`.
   - Canvas giữ `StudioAdmissionBanner` nổi để giáo viên có thể duyệt nhanh 1-chạm khi đang viết bảng.
   - TopBar icon `Icons.groups` hiện badge đỏ đếm số học sinh chờ.
2. **Hướng 2: Chế độ Tự động duyệt 100% (Zero-Click Auto Admit):**
   - Bỏ qua thao tác bấm duyệt, WebView2 tự động click duyệt ngay khi học sinh gõ cửa.
3. **Hướng 3: Modal Dialog xác nhận dạng Pop-up:**
   - Bật dialog toàn màn hình hỏi giáo viên duyệt hay từ chối (bị loại vì gây gián đoạn bài giảng).

## User's Direction
Người dùng chọn **Hướng 1**: Giáo viên chủ động kiểm soát và thấy rõ khu vực duyệt học sinh trực quan ngay trong thanh "Người tham gia", đồng thời hiển thị thông báo để duyệt dễ dàng.

## Open Questions & Fixes
- Sửa bộ lọc trong `meet_bridge_script.dart`: gỡ bỏ `b.offsetParent === null`, tìm kiếm cả `button, [role="button"]`, đối soát từ khóa 'cho phép', 'chấp nhận', 'admit', 'allow'.
- Bổ sung UI Waiting Room trong `StudioStudentsDrawer` khi `pendingAdmitCount > 0`.
- Kết nối hành động `meetService.admitAllPending()` vào cả Drawer và Banner.

## Risks
- Google Meet DOM có thể thay đổi cấu trúc popup snackbar khi cập nhật giao diện web.
- Mitigation: Quét từ khóa đa dạng trên toàn bộ DOM (`button`, `[role="button"]`, và text node cha) kết hợp MutationObserver định kỳ.
