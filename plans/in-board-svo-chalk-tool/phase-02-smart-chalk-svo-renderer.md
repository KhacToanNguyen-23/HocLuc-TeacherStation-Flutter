# Phase 02 — Smart Chalk S-V-O Model & Chalkboard Renderer

**Phase ID:** `phase-02-smart-chalk-svo-renderer`  
**Mapped Stories:** P1 (Chalk-Style Annotation Rendering), P2 (Toggle Visibility & Move/Persistence)  
**Status:** `not_started`

---

## 1. Objectives
Xây dựng model cấu trúc dữ liệu `SmartChalkAnnotation`, bộ render ngòi phấn chân thực (`ChalkUnderlinePainter`) vẽ các nét gạch chân phấn màu và chữ $S, V, O$ ôm sát dưới nét chữ viết tay, cùng khả năng ẩn/hiện, kéo thả di chuyển vị trí và lưu trữ toàn vẹn vào file bài giảng `.hls`.

---

## 2. Scope & Implementation Details

1. **Model `SmartChalkAnnotation` (`frontend/lib/models/smart_chalk_annotation.dart`):**
   - Thuộc tính:
     - `String id`: Mã định danh duy nhất (`svo-${timestamp}`).
     - `String source`: Nguồn chú thích (`'chalkboard'` hoặc `'pdf'`).
     - `int pageIndex`: Trang bảng phấn hoặc trang PDF chứa chú thích.
     - `String rawText`: Câu văn nguyên gốc (ví dụ: *"I go to school."*).
     - `Rect normalizedBounds`: Hình chữ nhật bao trọn câu văn trên tọa độ chuẩn hóa $[0.0, 1.0]$.
     - `List<ChalkWordToken> tokens`: Danh sách token của từng từ trong câu:
       - `String word`: Từ tiếng Anh (ví dụ: *"I"*, *"go"*, *"to"*, *"school"*).
       - `String? role`: Vai trò ngữ pháp (`'subject'`, `'verb'`, `'object'`, hoặc `null`).
       - `Rect relativeRect`: Tọa độ tương đối của từ trong `normalizedBounds`.
       - `Color color`: Màu phấn tương ứng:
         - Subject: Xanh pastel (`#89b4fa`).
         - Verb: Hồng tím pastel (`#f38ba8`).
         - Object: Cam vàng pastel (`#fab387`).
     - `bool isVisible = true`: Trạng thái ẩn/hiện độc lập của chú thích.
     - `Offset normalizedOffset = Offset.zero`: Độ dịch chuyển khi giáo viên kéo dời vị trí.
   - Serialization: `toJson()` và `fromJson()` đầy đủ, hỗ trợ lưu và nạp lại.

2. **Chalkboard Renderer (`frontend/lib/widgets/smart_chalk_overlay.dart`):**
   - Lớp `CustomPainter` (`ChalkUnderlinePainter`):
     - Vẽ nét gạch chân có độ sần/hạt phấn tự nhiên (thay vì một đường thẳng vector đơn điệu).
     - Vẽ nhãn ký hiệu $S, V, O$ đặt ngay ngắn dưới nét gạch chân với phông chữ dạng phấn viết bảng tinh tế.
     - Tự động ẩn toàn bộ nét vẽ khi `studio.chalkAnnotationsVisible == false` hoặc `annotation.isVisible == false`.
   - Lớp widget bọc tương tác:
     - Cho phép chạm để chọn chú thích (hiển thị viền phấn đứt đoạn mờ và nút xóa ✕).
     - Cho phép kéo thả (`onPanUpdate`) để dời cả cụm chú thích sang vị trí khác trên bảng.

3. **Tích hợp vào `InteractiveChalkboard` & `StudioState`:**
   - Trong `InteractiveChalkboard`: Đặt `SmartChalkOverlay` bên trong `InteractiveViewer` để phóng to/thu nhỏ (Zoom/Pan) hoàn toàn đồng bộ với các nét phấn `StrokeCanvas`.
   - Trong `StudioState`:
     - Bổ sung `Map<int, List<SmartChalkAnnotation>> pageChalkAnnotations`.
     - Bổ sung các phương thức: `addChalkAnnotation()`, `removeChalkAnnotation()`, `updateChalkAnnotationOffset()`, `clearChalkAnnotations()`.
     - Cập nhật `exportLessonJson()` lưu `smartChalkAnnotations` và `restoreFromJson()` khôi phục đầy đủ.

---

## 3. Files Affected
- `frontend/lib/models/smart_chalk_annotation.dart` *(Tạo mới)*
- `frontend/lib/widgets/smart_chalk_overlay.dart` *(Tạo mới)*
- `frontend/lib/widgets/interactive_chalkboard.dart` *(Cập nhật lớp phủ overlay)*
- `frontend/lib/models/studio_state.dart` *(Cập nhật quản lý danh sách chú thích & serialization)*
- `frontend/test/smart_chalk_annotation_test.dart` *(Kiểm thử model, renderer & serialization)*

---

## 4. Dependencies
- Phụ thuộc vào `StudioState` từ Phase 01.
- Là cơ sở hiển thị cho Phase 03 (chữ viết tay) và Phase 04 (tài liệu PDF).

---

## 5. Tests & Acceptance Criteria
- [ ] Chạy lệnh `flutter test test/smart_chalk_annotation_test.dart` pass 100%.
- [ ] Serialization test: `SmartChalkAnnotation.fromJson(annotation.toJson())` khôi phục chính xác 100% tọa độ, màu sắc và danh sách token.
- [ ] Khi thêm một `SmartChalkAnnotation` vào `StudioState`, widget overlay render đúng nét gạch chân và nhãn $S, V, O$ với các màu quy định (`#89b4fa`, `#f38ba8`, `#fab387`).
- [ ] Khi chuyển `chalkAnnotationsVisible = false`, toàn bộ các nét ký hiệu S-V-O ẩn đi; khi bật lại hiển thị đầy đủ tức thì.
- [ ] Kéo thả chú thích trên bảng, tọa độ dời được lưu chính xác và bài giảng xuất ra JSON chứa đúng dữ liệu.

---

## 6. Risks & Notes
- Render ngòi phấn có hạt nhám không được làm giảm hiệu năng khung hình: Dùng thuật toán tính toán đường cong nhẹ nhàng và cache `Picture` hoặc `Path` để giữ 60fps mượt mà.
