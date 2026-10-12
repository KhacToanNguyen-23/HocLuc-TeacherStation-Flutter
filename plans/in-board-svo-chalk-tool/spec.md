# Spec: In-Board Subject Tool Palette & S-V-O Handwritten Chalk Tool

**Date:** 2026-10-11  
**Status:** Ready  

---

## Problem Statement
Giáo viên giảng dạy bộ môn (như Tiếng Anh) cần các công cụ hỗ trợ tương tác trực tiếp lên bảng phấn và tài liệu bài giảng. Hiện tại, các tiện ích dạng modal/web iframe gây đứt gãy mạch bài giảng, buộc giáo viên phải rời khỏi bảng phấn. Hệ thống cần một khay công cụ bộ môn dạng dock nổi ngay trên bảng, cho phép giáo viên chỉ cần chạm tay vào câu chữ viết tay trên bảng hoặc câu trong tệp tài liệu là tự động vẽ nét gạch chân phấn màu và ký hiệu S, V, O như nét viết tay thật mà vẫn có thể bật/tắt ẩn hiện hoặc di chuyển thông minh.

---

## User Stories

- **[P1]** Là một giáo viên Tiếng Anh, tôi muốn mở khay công cụ bộ môn dạng dock nổi nhỏ gọn trên bảng phấn để truy cập nhanh các công cụ giảng dạy chuyên sâu mà không bị che khuất màn hình.  
  *Accepted when:* Khi kích hoạt tiện ích môn Tiếng Anh, xuất hiện một dock nổi thanh mảnh trên bảng phấn chứa các icon công cụ, có thể kéo thả di chuyển vị trí hoặc đóng lại.

- **[P1]** Là một giáo viên Tiếng Anh, tôi muốn chạm vào câu chữ viết tay trên bảng để tự động gạch chân và ký hiệu S, V, O bằng nét phấn màu ngay dưới nét chữ của tôi.  
  *Accepted when:* Chọn công cụ S-V-O và chạm vào vùng câu chữ viết tay (ví dụ: *"I go to school."*), hệ thống tự động gom nét, nhận diện câu và vẽ nét gạch chân phấn màu cùng ký hiệu $S$ (xanh), $V$ (hồng), $O$ (cam) ngay dưới từng từ tương ứng.

- **[P1]** Là một giáo viên Tiếng Anh, tôi muốn chạm/chọn câu văn trong tệp PDF đang mở để hệ thống tự động gạch chân và ký hiệu S-V-O ngay trên trang tài liệu.  
  *Accepted when:* Trong chế độ PDF hoặc Chia đôi (Split view), chọn công cụ S-V-O và chạm vào một câu tiếng Anh trong trang PDF, các nét gạch chân và nhãn $S, V, O$ được vẽ chính xác dưới dòng chữ trong tài liệu.

- **[P2]** Là một giáo viên, tôi muốn bấm nút mắt (👁️ Ẩn/Hiện) trên khay công cụ để giấu hoặc hiện lớp đáp án S-V-O nhằm tổ chức hoạt động hỏi đáp cho học sinh.  
  *Accepted when:* Bấm nút mắt trên dock, toàn bộ các nét ký hiệu S-V-O vừa sinh chuyển trạng thái ẩn; bấm lần nữa sẽ hiển thị lại đầy đủ đáp án.

- **[P2]** Là một giáo viên, tôi muốn các nét phấn ký hiệu S-V-O có thể kéo di chuyển linh hoạt hoặc tự động lưu trữ và khôi phục khi mở lại bài giảng `.hls`.  
  *Accepted when:* Kéo thả cụm ký hiệu S-V-O sang vị trí khác trên bảng thành công, lưu bài giảng và mở lại vẫn giữ nguyên các ký hiệu S-V-O.

- **[P3]** _(Out of scope cho phase này)_: Mở rộng thêm các công cụ bộ môn khác trên dock như: Tra nhanh phiên âm IPA khi chạm vào 1 từ đơn, hoặc phát hiện lỗi sai ngữ pháp bằng nét lượn sóng màu đỏ.

---

## Functional Requirements

1. **FR-01 (Subject Tool Dock):** Render widget dock nổi nhỏ gọn (`SubjectToolPalette`) trên `StageContainer` khi một extension môn học được kích hoạt. Dock chứa icon công cụ S-V-O, nút mắt Ẩn/Hiện, nút cấu hình/di chuyển và nút đóng.
2. **FR-02 (Handwriting Stroke Clustering):** Khi công cụ S-V-O đang bật và người dùng chạm vào bảng, hệ thống tính toán khoảng cách không gian (spatial bounding box) của các nét vẽ `BoardStroke` nằm trong bán kính vùng chạm để gom thành cụm nét câu văn.
3. **FR-03 (Handwriting Text Recognition & Parsing):** Nhận diện cụm nét chữ viết tay thành chuỗi văn bản tiếng Anh (hoặc tra cứu từ điển câu mẫu của bài giảng), sau đó bóc tách cú pháp thành các token với vai trò Subject (S), Verb (V), Object (O).
4. **FR-04 (Chalk-Style Annotation Rendering):** Vẽ nét gạch chân ngòi phấn và chữ ký hiệu $S, V, O$ đặt ngay ngắn dưới từng từ:
   - Chủ ngữ (Subject): Nét phấn màu xanh pastel (`#89b4fa`) + chữ **S**.
   - Động từ (Verb): Nét phấn màu hồng tím (`#f38ba8`) + chữ **V**.
   - Tân ngữ (Object): Nét phấn màu cam vàng (`#fab387`) + chữ **O**.
5. **FR-05 (PDF Sentence S-V-O):** Hỗ trợ chạm/chọn câu văn trong tệp PDF khi hiển thị qua `PdfStage`, tự động lấy chuỗi text và tọa độ dòng chữ để vẽ gạch chân S-V-O tương ứng lên lớp chú thích của PDF.
6. **FR-06 (Smart Toggle & Manipulation):** Cụm ký hiệu S-V-O được quản lý như một đối tượng thông minh (`SmartChalkAnnotation`), có thể bật/tắt hiển thị (ẩn/hiện đáp án) và kéo thả thay đổi vị trí.
7. **FR-07 (Persistence):** Các đối tượng S-V-O được serialize chuẩn hóa vào dữ liệu bài giảng và khôi phục toàn vẹn khi tải lại file `.hls`.

---

## Non-Functional Requirements

- **Performance:** Thời gian phản hồi từ lúc chạm vào câu chữ đến khi nét vẽ S-V-O phấn màu xuất hiện trên màn hình $\le 400\text{ ms}$.
- **Ergonomics & Visuals:** Nét gạch chân và chữ $S, V, O$ có độ nhám/hạt tự nhiên của ngòi phấn bảng học sinh, không gây cảm giác hình dán vuông vức thô cứng.
- **Portability:** Chạy mượt mà 60fps trên cả ứng dụng Flutter Windows Desktop và Flutter Web.

---

## Success Criteria

- [ ] Chạm vào dòng chữ viết tay trên bảng phấn, hệ thống tự động sinh nét gạch chân phấn màu và chữ $S, V, O$ ôm sát dưới nét chữ trong $< 400\text{ ms}$.
- [ ] Chạm vào câu văn trong file PDF tài liệu, hệ thống tự động sinh nét gạch chân và chữ $S, V, O$ chuẩn xác theo dòng chữ tài liệu.
- [ ] Bấm nút mắt trên khay dock, toàn bộ nét ký hiệu S-V-O ẩn/hiện tức thì không độ trễ.
- [ ] Kéo thả di chuyển cụm ký hiệu S-V-O mượt mà, lưu bài giảng và mở lại vẫn nguyên vẹn.
- [ ] Toàn bộ test suite đạt $100\%$ Green, static analysis $0$ errors.

---

## Out of Scope

- Bàn phím ảo nhận diện toán học hoặc công thức hóa học (dành cho plugin Toán/Hóa học sau này).
- Tích hợp giọng đọc AI phát âm câu văn (sẽ làm trong công cụ phát âm riêng).

---

## Assumptions

- Giáo viên viết câu văn trên bảng phấn theo hướng nằm ngang tương đối thẳng hàng và có khoảng cách giữa các từ.
- Tệp PDF có sẵn text layer hoặc có thể trích xuất văn bản dòng khi người dùng tương tác.
