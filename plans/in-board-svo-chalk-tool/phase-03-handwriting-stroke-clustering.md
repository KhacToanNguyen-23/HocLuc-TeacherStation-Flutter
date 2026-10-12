# Phase 03 — Handwriting Stroke Clustering & Chalkboard Touch Trigger

**Phase ID:** `phase-03-handwriting-stroke-clustering`  
**Mapped Stories:** P1 (Handwriting Stroke Touch Trigger & S-V-O Generation)  
**Status:** `not_started`

---

## 1. Objectives
Xây dựng thuật toán gom cụm nét vẽ chữ viết tay (`StrokeClusterer`), nhận diện vùng câu văn giáo viên vừa viết trên bảng phấn, bóc tách cấu trúc S-V-O và tự động sinh các nét gạch chân phấn màu cùng ký hiệu $S, V, O$ ôm sát chân nét chữ trong thời gian dưới $400\text{ ms}$.

---

## 2. Scope & Implementation Details

1. **Thuật toán Gom Cụm Nét Vẽ (`frontend/lib/services/stroke_clusterer.dart`):**
   - **Đầu vào:** Tọa độ chạm chuẩn hóa `Offset touchPoint` và danh sách nét vẽ `List<BoardStroke> strokes` trên trang bảng hiện tại.
   - **Bước 1 — Spatial Proximity Filter:** Lọc các nét vẽ có khoảng cách gần điểm chạm ($d \le 0.15$ trên không gian normalized $1.0 \times 1.0$).
   - **Bước 2 — Horizontal Line Grouping:** Nhóm các nét vẽ nằm cùng một dòng viết (chênh lệch tung độ tâm nét $\Delta y \le 0.045$).
   - **Bước 3 — Word Clustering:** Phân tách dòng chữ thành các cụm từ (Word Clusters) bằng cách phát hiện các khoảng trống hoành độ ($\Delta x > 0.018$ giữa hai nét kế tiếp).
   - **Bước 4 — Sentence Parsing & Token Mapping:**
     - Xác định nội dung câu văn tiếng Anh thông qua bộ phân tích `EnglishSentenceAnalyzer` kết hợp từ điển mẫu bài giảng hoặc phân tách tỉ lệ từ.
     - Tính toán `Rect relativeRect` cho từng từ ngữ $S, V, O$ tương ứng với bounding box của từng cụm nét viết tay thực tế.
     - Trả về đối tượng `SmartChalkAnnotation` hoàn chỉnh với vị trí nét gạch chân nằm ngay sát đáy nét vẽ.

2. **Chuyển đổi Cử chỉ Chạm trên Bảng Phấn (`frontend/lib/widgets/stroke_canvas.dart`):**
   - Kiểm tra điều kiện: Nếu `studio.activeSubjectTool == 'svo'`:
     - Cursor chuột chuyển sang dạng chọn mục tiêu (`SystemMouseCursors.click`).
     - Khi giáo viên chạm ngón tay hoặc click chuột (`onTapDown`):
       - Không sinh ra nét vẽ phấn mới.
       - Gọi hàm `studio.analyzeHandwritingAt(normPoint)` để chạy gom nét và sinh chú thích S-V-O.
       - Nếu không có nét vẽ nào quanh điểm chạm: Hiển thị phản hồi nhẹ hướng dẫn chạm vào dòng chữ đã viết.

3. **Tích hợp vào `StudioState` (`frontend/lib/models/studio_state.dart`):**
   - Viết hàm `void analyzeHandwritingAt(Offset touchPoint)`:
     - Gọi `StrokeClusterer.clusterAndAnalyze(touchPoint, currentStrokes)`.
     - Thêm chú thích S-V-O vừa tạo vào `pageChalkAnnotations[page]` và gọi `notifyListeners()`.
     - Phản hồi tức thì trong $< 400$ms, không mở bất kỳ modal hay pop-up nào.

---

## 3. Files Affected
- `frontend/lib/services/stroke_clusterer.dart` *(Tạo mới)*
- `frontend/lib/models/studio_state.dart` *(Cập nhật hàm `analyzeHandwritingAt`)*
- `frontend/lib/widgets/stroke_canvas.dart` *(Cập nhật điều hướng cử chỉ chạm khi S-V-O tool bật)*
- `frontend/test/handwriting_stroke_clustering_test.dart` *(Kiểm thử thuật toán gom cụm nét và xử lý chạm)*

---

## 4. Dependencies
- Phụ thuộc vào `SmartChalkAnnotation` (Phase 02) và `SubjectToolPalette` (Phase 01).
- Tái sử dụng bộ bóc tách cú pháp `EnglishSentenceAnalyzer`.

---

## 5. Tests & Acceptance Criteria
- [ ] Chạy lệnh `flutter test test/handwriting_stroke_clustering_test.dart` pass 100%.
- [ ] Giả lập một câu viết tay gồm 4 từ (*"I"*, *"go"*, *"to"*, *"school"*): Khi chạm vào vùng giữa câu, thuật toán gom đúng 4 cụm từ và trả về bounding box khớp với tọa độ nét vẽ.
- [ ] Chú thích S-V-O được tạo có đủ 3 vai trò: Subject (xanh), Verb (hồng), Object (cam).
- [ ] Khi công cụ S-V-O đang bật, thao tác chạm vào bảng không làm vẽ thêm nét phấn thừa.
- [ ] Thời gian xử lý gom nét và sinh chú thích đạt dưới $400\text{ ms}$.

---

## 6. Risks & Notes
- Trường hợp nét chữ viết dính liền không có khoảng cách: Thuật toán chia đều tỉ lệ bounding box theo số lượng từ của câu được nhận diện, đảm bảo nét gạch chân luôn cân đối đẹp mắt.
