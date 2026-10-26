# Specification: Math Studio UI/UX & Chalkboard Export Complete Fix

**Status:** Approved  
**Date:** 2026-10-26  
**Module:** `plugins/math_studio` & `frontend/lib/features/{plugin_engine, studio_board}`  
**Tracking Issue/Phase:** UI Audit & Chalkboard Export Polish  

---

## 1. Objective & Scope

### 1.1 Objective
Giải quyết triệt để toàn bộ 5 vấn đề UI/UX phát hiện qua kiểm tra thực tế trên ứng dụng:
1. **Đồng bộ tự động Cache `%LOCALAPPDATA%`**: Đảm bảo mỗi khi khởi chạy hoặc mở plugin, `PluginManager` luôn đồng bộ bản `.hlep` / thư mục plugin mới nhất vào `%LOCALAPPDATA%\HocLuc\plugins\<id>\v<version>\` (không bị kẹt ở bản cache cũ).
2. **Hộp thoại Modal Cố định & Căn Chính Tâm Vùng Bảng**:
   - Kích thước cố định chuẩn `980 × 560px` (`movable: false`).
   - Sử dụng `LayoutBuilder` (hoặc `Center`) dựa trên không gian thực tế của vùng bảng đen thay vì `MediaQuery.of(context).size`, đảm bảo modal nằm ngay chính tâm vùng bảng, cách đều 4 cạnh và **không bao giờ chạm hay bị cắt bởi thanh "Ghi chú Trang 1/1"** ở đáy.
   - Lớp nền mờ (Dark Scrim Backdrop `Color(0x66000000)`) làm nổi bật hộp thoại đè lên bảng đen.
3. **Định vị Nhãn Cực trị & Chữ Sắc nét trên JSXGraph**:
   - Điểm **Cực đại ($CĐ$)**: Đặt nhãn nằm hẳn **phía TRÊN đỉnh lồi** (`offset: [0, 16]`, `anchorX: 'middle'`).
   - Điểm **Cực tiểu ($CT$)**: Đặt nhãn nằm hẳn **phía DƯỚI đáy lõm** (`offset: [0, -18]`, `anchorX: 'middle'`).
   - Bổ sung viền halo sáng (`paint-order: stroke; stroke: #ffffff; stroke-width: 3px;`) để chữ luôn nổi rõ, không đè lên đường gióng nét đứt hay trục tọa độ.
4. **Xuất SVG Ghim lên Bảng Đen Chuẩn Sư phạm (Phương án A)**:
   - Tự động **ẩn lưới phụ của JSXGraph** khi xuất SVG để đồ thị tiệp hoàn toàn vào lưới ô vuông sẵn có của bảng phấn.
   - Tự động **ẩn các chấm tròn điều khiển kéo cận (gliders)** chỉ dùng trong lúc chỉnh sửa.
   - Chuyển đổi cả thuộc tính XML `fill`/`stroke` lẫn inline CSS `style="fill: ..."` của mọi nhãn chữ ($CĐ, CT, a, b, x, y, O$) sang màu trắng/vàng sáng nổi bật trên nền bảng đen.
5. **Khung Chọn Nét Đứt Đỏ Đô & Thanh Công Cụ Nổi Chuẩn NoteRenderer**:
   - Đảm bảo toàn bộ diện tích ảnh ghim nhận click nhạy (`HitTestBehavior.opaque`).
   - Khung chọn nét đứt màu đỏ đô (`#8B1D24`), 8 mấu vuông trắng viền đỏ đô, cần xoay phía trên và thanh công cụ nổi 10 nút chuẩn mẫu tham chiếu.

---

## 2. User Stories & Acceptance Criteria

- **US1 (P1 - Modal Centering & Fixed Size)**: Là giáo viên, khi mở công cụ Đồ thị hàm số, tôi muốn hộp thoại kích thước cố định (`980 × 560px`) hiện nổi đè ngay chính giữa vùng bảng đen, không bị lệch phải và không bị thanh "Ghi chú Trang 1/1" che khuất nút bấm ở đáy.
- **US2 (P1 - Clean Chalkboard Pinning - Option A)**: Là giáo viên, khi bấm "Ghim vào bảng", tôi muốn hình đồ thị trên bảng đen có nền trong suốt, không bị vướng lưới trắng của JSXGraph hay 2 nút kéo đỏ, và các chữ $CĐ, CT, a, b$ phải hiện rõ ràng màu sáng trên nền bảng đen.
- **US3 (P1 - Crisp Non-Overlapping Labels)**: Là giáo viên, tôi muốn nhãn $CĐ, CT$ trên đồ thị nằm ở đỉnh trên / đáy dưới thoáng đãng, không đè lên đường gióng nét đứt hay trục $Oy$.
- **US4 (P1 - Automatic Local Cache Sync)**: Là nhà phát triển/giáo viên, khi gói `.hlep` trong project được cập nhật, ứng dụng phải tự động cập nhật bản giải nén trong `%LOCALAPPDATA%` mà không dùng lại file cũ.

---

## 3. Measurable Success Criteria

1. **Modal Placement**: Khoảng cách từ mép trên/dưới của modal đến mép vùng bảng luôn $\ge 36\text{px}$, hiển thị 100% footer và nút *"Ghim vào bảng"*.
2. **SVG Export Visibility**: 100% các phần tử `<text>` và `<tspan>` trong SVG xuất ra bảng đen có màu sáng (`#ffffff`, `#fde047`, hoặc `#93c5fd`), 0 phần tử lưới phụ (`strokeOpacity < 0.3`) và 0 glider kéo cận bị lọt vào SVG tĩnh.
3. **Architecture Gate**: 12/12 Invariants trong `node scripts/run_architecture_check.mjs` và 5/5 bộ unit test đạt 100%.

