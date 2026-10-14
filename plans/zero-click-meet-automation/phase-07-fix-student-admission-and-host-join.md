# Phase 7: Fix In-App Student Admission Banner & Host Join Verification

**Status:** Completed  
**Covers:** [P1] In-App Student Admission, [P1] Host In-Call Reliability, [P2] Auto-Admit  
**Risk:** Normal  

---

## Context & Root Cause
1. **`StudioAdmissionBanner` chưa được gắn vào giao diện Studio:**
   - Component `StudioAdmissionBanner` đã hoàn thành nhưng chưa được đặt trong `Stack` của `StudioScreen`, khiến thông báo không hiển thị trên màn hình dù có học sinh xin vào.
2. **Bộ lọc từ khóa duyệt học sinh thiếu từ "Cho phép":**
   - Google Meet tiếng Việt hiển thị nút "Cho phép" (hoặc "Chấp nhận"). Script hiện tại chỉ tìm `chấp nhận` và `admit`, bỏ sót từ `cho phép`.
3. **Độ tin cậy của việc vào phòng ngầm (Host Auto-Join):**
   - Nút "Tham gia ngay" có thể bị `disabled` trong vài giây đầu khi Google Meet nạp thiết bị. Cần đảm bảo chỉ xác nhận vào phòng khi nút đỏ "Rời khỏi cuộc gọi" xuất hiện.
   - Khi chuyển từ Lobby sang Studio, đảm bảo WebView2 ngầm đã ở trạng thái `IN_CALL`.

---

## Tasks

### Task 7.1: Gắn `StudioAdmissionBanner` vào `StudioScreen`
- **File:** [`frontend/lib/screens/studio_screen.dart`](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/frontend/lib/screens/studio_screen.dart)
- Import `import '../widgets/studio/studio_admission_banner.dart';`.
- Đặt `StudioAdmissionBanner(meetService: MeetAutomationService())` vào `Stack` chính của màn hình Studio (nổi ở góc trên bên phải hoặc chính giữa phía trên canvas).

### Task 7.2: Mở rộng từ khóa nhận diện duyệt học sinh trong `MeetBridgeScript`
- **File:** [`frontend/lib/services/meet_bridge_script.dart`](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/frontend/lib/services/meet_bridge_script.dart)
- Mở rộng bộ lọc tìm nút duyệt trong `scanHandsAndKnocks()` và `admitAll()`:
  Hỗ trợ `'cho phép'`, `'chấp nhận'`, `'admit'`, `'allow'`, `'cho vào'`, `'chấp nhận tất cả'`, `'cho phép tất cả'`, `'admit all'`.
- Khi `admitButtons.length == 0`, gửi sự kiện `ADMIT_REQUEST` với `pendingCount: 0` để tự động ẩn Banner khi học sinh đã được duyệt hết.

### Task 7.3: Tối ưu hóa Host Auto-Join & Xác nhận `IN_CALL`
- **File:** [`frontend/lib/services/meet_bridge_script.dart`](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/frontend/lib/services/meet_bridge_script.dart)
- Trong `attemptAutoJoin()`:
  - Chỉ coi là join thành công khi phát hiện nút `inCall` (nút rời khỏi cuộc gọi đỏ).
  - Không click khi nút `joinBtn.disabled == true`.
- Trong `MeetAutomationService`:
  - Cung cấp hàm `Future<void> ensureHostJoined()` để gọi khi chuyển vào Studio nếu chưa ở trong cuộc gọi.

### Task 7.4: Hiển thị Badge thông báo học sinh trên Header Studio
- **File:** [`frontend/lib/widgets/studio/studio_top_bar.dart`](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/frontend/lib/widgets/studio/studio_top_bar.dart)
- Bổ sung chấm đỏ / số lượng học sinh chờ duyệt trên icon `Icons.groups` để giáo viên nhìn thấy ở cả thanh Header lẫn Banner trên bảng vẽ.

### Task 7.5: Kiểm thử tự động
- Chạy `flutter test` đảm bảo toàn bộ unit và widget tests pass 100%.

---

## Verification
- Lệnh kiểm thử: `flutter test`
- Tiêu chí:
  - `StudioAdmissionBanner` xuất hiện khi `pendingAdmitCount > 0`.
  - Bấm "Cho vào tất cả" kích hoạt `MeetBridge.admitAll()`.
  - Bộ từ khóa 'cho phép' / 'chấp nhận' bắt chính xác popup Google Meet tiếng Việt.
