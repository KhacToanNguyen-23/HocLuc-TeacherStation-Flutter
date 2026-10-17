# Spec: Tự đồng bộ Google Classroom sau khi tạo lớp

**Date:** 2026-10-17
**Status:** Implemented

---

## Problem Statement

Giáo viên hiện phải bấm Đồng bộ thủ công sau khi tạo lớp trên màn hình kết nối Google Classroom. Nếu Google còn yêu cầu chấp nhận lớp, họ phải quay lại HocLucStation và bấm Đồng bộ lần nữa để lấy thành viên.

## User Stories

- **[P1]** Là giáo viên, tôi muốn HocLucStation tự đồng bộ thành viên sau khi tạo lớp để không cần bấm Đồng bộ ngay sau thao tác tạo.
  Accepted when: sau khi thao tác tạo lớp thành công, HocLucStation hiển thị kết quả đồng bộ mà backend đã thực hiện trong yêu cầu tạo; không phát thêm yêu cầu đồng bộ trùng và không cần bấm Đồng bộ.

- **[P1]** Là giáo viên, tôi muốn HocLucStation kiểm tra lại khi quay về app sau khi chấp nhận lớp trong Classroom để không cần bấm Đồng bộ lần nữa.
  Accepted when: nếu lần đồng bộ sau khi tạo báo lớp chưa được kích hoạt, một lần app resume/focus kế tiếp tự gọi đồng bộ thành viên tối đa 1 lần; không cần thao tác Đồng bộ thủ công.

- **[P1]** Là giáo viên, tôi muốn biết khi lớp chưa được Google kích hoạt để biết cần chấp nhận lớp trong Classroom.
  Accepted when: kết quả đồng bộ chưa sẵn sàng hiển thị hướng dẫn mở Classroom và chấp nhận lớp, đồng thời không báo như thể thành viên đã được đồng bộ.

- **[P1]** Là giáo viên, tôi muốn HocLucStation thông báo kết quả tự kiểm tra ngay trong app để biết lớp đã kích hoạt và thành viên đã được đồng bộ hay chưa.
  Accepted when: sau lần kiểm tra tự động, giao diện lớp hiển thị thông báo phù hợp cho trạng thái đang chờ, đã kích hoạt/đồng bộ thành công, hoặc lỗi; không gửi thông báo hệ điều hành.

- **[P2]** Là giáo viên, tôi muốn thấy trạng thái đồng bộ đang chạy và kết quả của nó để hiểu app đang làm gì.
  Accepted when: giao diện phân biệt trạng thái đang đồng bộ, hoàn tất và thất bại/chưa sẵn sàng trong cùng một luồng lớp.

---

## Functional Requirements

1. FR-01: Dùng kết quả đồng bộ mà yêu cầu tạo lớp hiện tại trả về; không gọi thêm endpoint đồng bộ nếu yêu cầu tạo đã thực hiện đồng bộ.
2. FR-02: Nếu `courseState == PROVISIONED`, hiển thị hướng dẫn chấp nhận lớp trong Classroom và ghi nhận lớp cần kiểm tra lại. Với các trạng thái khác không phải `ACTIVE` hoặc `PROVISIONED`, hiển thị cần chú ý và không tự retry.
3. FR-03: Khi Flutter báo app vào trạng thái `AppLifecycleState.resumed` và lớp đang mở có `courseState == PROVISIONED`, tự gọi lại endpoint đồng bộ hiện có cho lớp đó.
4. FR-04: Không chạy đồng thời nhiều yêu cầu đồng bộ cho cùng một lớp; thao tác Đồng bộ thủ công và tự động dùng chung guard/kết quả, các sự kiện trùng khi yêu cầu đang chạy phải được gộp hoặc bỏ qua.
5. FR-05: Khi đồng bộ thành viên hoàn tất, cập nhật danh sách và trạng thái lớp trên giao diện mà không yêu cầu người dùng bấm Đồng bộ; hiển thị thông báo kết quả ngay trong app.
6. FR-06: Phân biệt lỗi quyền/API với trạng thái lớp đang chờ kích hoạt; hiển thị lỗi phù hợp với kết quả trả về.
7. FR-07: Không tự chạy polling nền định kỳ trong phạm vi này. Giữ thao tác Đồng bộ thủ công làm cách kiểm tra lại bổ sung.

---

## Non-Functional Requirements

- Performance: bắt đầu yêu cầu tự đồng bộ trong vòng 2 giây sau khi tạo lớp thành công hoặc nhận app resume/focus, trừ khi một yêu cầu cho lớp đó đang chạy.
- Security: dùng cùng thông tin xác thực Google và quyền API hiện có của thao tác Đồng bộ; không ghi token hoặc dữ liệu nhạy cảm vào log.
- Availability: lỗi mạng/API phải kết thúc trạng thái đang chạy và cho phép lần resume/focus sau hoặc thao tác thủ công thử lại.

---

## Success Criteria

- [x] Ca tạo lớp thành công dùng kết quả đồng bộ sẵn có mà không phát thêm yêu cầu đồng bộ trùng hoặc cần click Đồng bộ; verified by `completing a created course reflects its sync response without duplicate sync`.
- [x] Lớp `PROVISIONED` hiển thị hướng dẫn chấp nhận lớp và không báo đồng bộ thành viên hoàn tất; `DECLINED`, `ARCHIVED` và `SUSPENDED` không tự retry; verified by Classroom state widget tests.
- [x] Sau khi lớp được chấp nhận và app resume, thành viên được tự kiểm tra mà không cần click Đồng bộ; verified by `resume syncs a loaded PROVISIONED course and applies ACTIVE response`.
- [x] Resume trùng khi yêu cầu đang chạy không tạo thêm yêu cầu đồng bộ cho cùng lớp; verified by `duplicate resumes coalesce and manual sync stays disabled while syncing`.
- [x] Kết quả tự kiểm tra hiển thị banner trong app phản ánh trạng thái pending, progress, success, partial hoặc error; verified by Google Workspace widget tests.

## Verification

- `flutter test --no-pub --reporter expanded test/google_workspace_test.dart` — 33 passed.
- `flutter test --no-pub --reporter expanded test/architecture_test.dart` — 5 passed.
- `mvn -Dtest=GoogleIntegrationTest test` — 47 passed, 0 failures (no backend changes in this feature).
- Final code review — APPROVED, no findings.

---

## Out of Scope

- Đồng bộ định kỳ khi app chạy nền.
- Tự mở Google Classroom hoặc tự chấp nhận lớp thay người dùng.
- Thay đổi quy trình tạo lớp, mời học sinh hoặc bắt đầu buổi dạy.
- Tự đồng bộ sau mọi loại thao tác khác ngoài tạo lớp và app resume/focus của luồng đang chờ kích hoạt.

---

## Assumptions

- Nút Đồng bộ hiện tại đồng bộ thành viên của lớp đang chọn; luồng tự động sẽ dùng lại cùng nghiệp vụ và quyền API.
- Backend hiện thực hiện kiểm tra trạng thái và đồng bộ thành viên trong luồng tạo lớp khi lớp đã `ACTIVE`; frontend không cần gửi yêu cầu đồng bộ thứ hai sau khi tạo.
- Google Classroom API `courseState == ACTIVE` nghĩa là lớp đã kích hoạt; `PROVISIONED` nghĩa là lớp đã tạo nhưng chưa kích hoạt. Backend hiện lưu `courseState` và khi đồng bộ sẽ đọc mới trạng thái lớp từ Google trước khi lấy roster.
- Các trạng thái không phải `ACTIVE`/`PROVISIONED` như `DECLINED`, `ARCHIVED` và `SUSPENDED` không được coi là chờ giáo viên chấp nhận và không tự retry.
- Thao tác chấp nhận lớp trong Classroom do giáo viên thực hiện; HocLucStation chỉ kiểm tra lại sau khi được đưa về foreground.
- Trạng thái pending chỉ cần tồn tại trong phiên màn hình Google Workspace; Classroom được mở bên ngoài và màn hình này vẫn mounted.
- Trạng thái kết quả hiển thị bằng banner trong thẻ lớp, không cần snackbar hay thông báo hệ điều hành.
