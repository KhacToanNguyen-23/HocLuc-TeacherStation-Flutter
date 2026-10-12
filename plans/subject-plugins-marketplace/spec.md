# Spec: Hệ Thống Tiện Ích Môn Học & Cửa Hàng Plugin Chuẩn Google Meet

**Date:** 2026-10-12
**Status:** Approved

---

## Problem Statement

Hiện tại mục "TIỆN ÍCH MÔN HỌC [Plugins]" trong thanh menu chỉ có dòng thông báo mẫu mà chưa có luồng cài đặt thực tế. Giáo viên dạy online cho các môn THPT và kỳ thi Đánh giá năng lực (ĐGNL) cần một hệ sinh thái tiện ích linh hoạt (máy tính Casio, vẽ đồ thị hàm số, đồng hồ bấm giờ ĐGNL, bảng tuần hoàn...). Cần xây dựng luồng cài đặt tiện ích chuẩn Google Meet (Panel Hoạt động bên phải), kiến trúc hướng đối tượng (OOP) sạch sẽ, hỗ trợ cả công cụ trên bảng lẫn cửa sổ nổi.

---

## User Stories

- **[P1]** As a giáo viên, I want khi bấm vào "Cài thêm tiện ích môn" (hoặc icon Tiện ích trên thanh công cụ), một bảng bên phải (Right Activities Panel kiểu Google Meet) trượt ra hiển thị các tiện ích có thể cài đặt, so that tôi dễ dàng khám phá và cài đặt mà không bị che khuất màn hình giảng dạy.
  Accepted when: Bấm nút mở ngay panel bên phải với thiết kế chuẩn Google Meet Activities (tiêu đề, nút đóng, danh sách card tiện ích).

- **[P1]** As a giáo viên, I want danh sách plugin hiển thị thống nhất với icon đặc trưng và nút "Cài đặt" / "Gỡ cài đặt", so that tôi dễ dàng chọn đúng công cụ mình cần.
  Accepted when: Mỗi plugin có icon, tên, trạng thái (Đã cài đặt / Chưa cài đặt), bấm "Cài đặt" sẽ chuyển sang trạng thái đã kích hoạt và lưu lại phiên.

- **[P1]** As a giáo viên, I want sau khi cài đặt, plugin xuất hiện ngay trên danh sách tiện ích của Studio để mở ra dạng cửa sổ nổi (Floating Widget) hoặc thanh công cụ bảng, so that tôi sử dụng trực tiếp trong lúc giảng bài.
  Accepted when: Bấm mở tiện ích đã cài đặt sẽ hiển thị cửa sổ nổi có thể di chuyển trên màn hình giảng dạy.

- **[P2]** As a lập trình viên, I want kiến trúc mã nguồn được mô hình hóa theo OOP (`SubjectPlugin` abstract class, `PluginManager`), so that dễ dàng mở rộng thêm các plugin mới trong tương lai.
  Accepted when: Mã nguồn triển khai kế thừa đa hình từ `SubjectPlugin`.

- **[P2]** As a lập trình viên, I want bộ test `flutter test` tiếp tục pass 100% (45/45).
  Accepted when: Lệnh `flutter test` chạy thành công.

---

## Functional Requirements

1. **FR-01 (Mô hình Hướng đối tượng OOP `SubjectPlugin`):**
   - Lớp cơ sở trừu tượng `SubjectPlugin` chứa:
     - `String id`: định danh duy nhất (vd: `casio_fx580`, `desmos_graph`, `dgnl_timer`, `periodic_table`).
     - `String name`: tên hiển thị (vd: `Máy tính Casio fx-580`, `Vẽ đồ thị Desmos`, `Đồng hồ bấm giờ ĐGNL`).
     - `IconData icon`: biểu tượng nhận diện.
     - `Widget buildFloatingWidget(BuildContext context)`: giao diện khi mở cửa sổ nổi.
     - `Widget? buildBoardTool(BuildContext context)`: giao diện nút công cụ trên thanh bảng.
2. **FR-02 (`PluginManager` Quản lý Vòng đời Plugin):**
   - Đăng ký danh sách plugin cốt lõi.
   - Quản lý trạng thái: `isInstalled(id)`, `install(id)`, `uninstall(id)`.
   - Lưu trữ danh sách plugin đã cài đặt bằng `SharedPreferences`.
3. **FR-03 (Right Side Panel - Bảng Tiện ích Chuẩn Google Meet):**
   - Khi bấm "Cài thêm tiện ích môn" trong `StudioLessonsDrawer` hoặc icon Tiện ích trên thanh điều khiển:
     - Mở Panel trượt từ mép phải màn hình (Right Slide Drawer / Side Sheet).
     - Tiêu đề: **Hoạt động & Tiện ích** (Activities).
     - Danh sách thẻ tiện ích (cards): Icon trong khung tròn/bo góc, Tên tiện ích, Nút "Cài đặt" (Elevated) hoặc "Gỡ cài đặt" / "Mở" (Outlined/Text).
4. **FR-04 (Tương tác trong Studio sau khi Cài đặt):**
   - Trong `StudioLessonsDrawer`, mục "TIỆN ÍCH MÔN HỌC" hiển thị các plugin đã cài đặt.
   - Bấm vào tiện ích đã cài đặt sẽ mở cửa sổ nổi mini (Floating Window) trên khu vực giảng dạy.

---

## Non-Functional Requirements

- **Aesthetics:** Giao diện tối giản, thanh lịch, chuẩn tông màu và bố cục của Google Meet Activities.
- **Maintainability:** OOP sạch, tuân thủ SOLID principles, dễ dàng thêm plugin mới chỉ bằng việc tạo thêm một class con kế thừa `SubjectPlugin`.

---

## Success Criteria

- [ ] Bấm "Cài thêm tiện ích môn" mở ra Right Side Panel chuẩn Google Meet.
- [ ] Danh sách plugin thống nhất, bấm "Cài đặt" lưu thành công trạng thái.
- [ ] Sau khi cài, plugin hiển thị trong menu tiện ích và có thể mở dùng ngay.
- [ ] `flutter test` pass 45/45.
