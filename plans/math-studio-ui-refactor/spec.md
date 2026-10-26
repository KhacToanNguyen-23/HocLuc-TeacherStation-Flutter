# Spec: Học Lực Math Studio UI Refactor (Canva-Style Object Manipulation & Academic Fixed Dock)

**Date:** 2026-10-25  
**Status:** Ready  

---

## Problem Statement

Giao diện Math Studio hiện tại còn mang tư duy cửa sổ hộp desktop cũ, chứa nhiều emoji/chú thích thừa, gán nhãn sai lệch tên "NoteRenderer", thanh input còn lỗi và tính năng kéo nắn điểm đồ thị bị vô hiệu hóa. Khi ghim lên bảng, sticker bị đóng khung cố định thiếu linh hoạt. Refactor này biến plugin thành một **Thanh Dock Toán Học Cố Định (Academic Light)** tinh gọn và nâng cấp đối tượng trên bảng thành **Transform Controls chuẩn Canva** cho phép co giãn 8 chốt, xoay tự do và kéo nắn cực trị 2 chiều trực tiếp trên mặt bảng.

---

## User Stories

### [P1] Thanh Dock Toán Học Học Thuật (Academic Fixed Dock)
- **[P1]** As a giáo viên dạy Toán, I want a compact fixed dock on the chalkboard so that màn hình giảng dạy thoáng đãng và không bị các cửa sổ modal che khuất bài giảng.  
  *Accepted when:* Plugin hiển thị dạng thanh Dock cố định với tone màu sáng academic (`#FFFFFF`, `#F8FAFC`, `#0F172A`), bỏ 100% emoji, thay bằng vector icon toán học thanh mảnh, và nhãn thương hiệu ghi đúng **Học Lực Math Studio**.
- **[P1]** As a giáo viên, I want an error-free math formula input bar so that gõ các biểu thức đa thức, phân số, căn thức mượt mà và hiển thị công thức chính xác.  
  *Accepted when:* Ô nhập hỗ trợ gõ phím liên tục không mất focus, không lỗi caret, tự động cập nhật đồ thị và bảng biến thiên theo thời gian thực ($< 16\text{ms}$).

### [P1] Canva-Style Object Manipulation trên Bảng Phấn
- **[P1]** As a giáo viên, I want visual objects on the chalkboard to behave like Canva/Illustrator graphics so that hình vẽ xuất hiện trong suốt tự nhiên và chỉ hiện điều khiển khi chạm vào.  
  *Accepted when:* Ở trạng thái bình thường (Deselected), đối tượng 100% trong suốt hòa vào mặt bảng, không có khung viền hay header. Khi chạm/click vào đối tượng (Selected), xuất hiện Bounding Box với 8 chốt kéo (4 góc tỷ lệ, 4 cạnh co giãn), 1 cuống xoay $\theta \in [0^\circ, 360^\circ]$, và thanh tác vụ nổi `[ Sửa ]`, `[ Phát quay ]`, `[ Nhân bản ]`, `[ Xóa ]`. Chạm ra ngoài mặt bảng $\rightarrow$ ẩn toàn bộ điều khiển.
- **[P1]** As a giáo viên, I want to drag extreme points directly on the board so that đồ thị uốn lượn và công thức toán học thay đổi tương ứng.  
  *Accepted when:* Khi đồ thị được chọn trên bảng, các điểm cực trị (CĐ, CT) hiển thị chốt tương tác; giáo viên kéo điểm bằng tay/bút $\rightarrow$ hệ số hàm số tính toán lại và nhãn công thức cập nhật ngay tại chỗ.

### [P2] Thu phóng và Nét vẽ Chuẩn mực Sư phạm
- **[P2]** As a giáo viên, I want smooth zooming and crisp mathematical typography so that đồ thị và hệ trục tọa độ sắc sảo, số liệu thanh mảnh dễ đọc.  
  *Accepted when:* Thu phóng bằng con lăn chuột (Mouse wheel / Pinch) mượt mà 60 FPS; trục tọa độ, vạch chia và nhãn số đạt độ tương phản cao, phông chữ Cambria Math/Computer Modern thanh lịch.

---

## Functional Requirements

1. **FR-01: Academic Dock Interface:** Giao diện plugin đóng gói dạng thanh Dock bo tròn mỏng, tone màu học thuật sáng, gỡ bỏ toàn bộ emoji và text mô tả rườm rà.
2. **FR-02: Formula Input Stability:** Sửa lỗi parsing và caret trong ô input, đồng bộ 2 chiều giữa chuỗi thô và visual typeset.
3. **FR-03: Selection State Toggle:** Quản lý `selectedStickerId` trong `StudioState`. Chỉ hiển thị khung Transform Controls khi đối tượng đang được chọn; nhấp vào vùng trống của bảng thì giải phóng chọn lựa.
4. **FR-04: 8-Handle Transform & Rotation:**
   - 4 chốt góc: Co giãn tỷ lệ đồng dạng (Aspect-ratio locked scale).
   - 4 chốt cạnh: Co giãn tự do theo chiều ngang hoặc dọc.
   - 1 cuống xoay đỉnh: Xoay đối tượng tự do theo góc $\theta$.
5. **FR-05: Direct Curve Manipulation on Chalkboard:**
   - Gắn hit-test bắt sự kiện chạm vào các điểm cực trị ($CĐ, CT$) trên SVG đồ thị.
   - Khi kéo điểm $\rightarrow$ gọi `computeFormulaFromDrag` và cập nhật lại SVG ngay trên bảng phấn.
6. **FR-06: Brand Correction:** Xóa bỏ toàn bộ từ khóa "NoteRenderer", thay thế bằng **Học Lực Math Studio** trong `manifest.json`, tiêu đề, metadata và SVG xuất bản.

---

## Non-Functional Requirements

- **Performance:** Thao tác kéo nắn đồ thị và xoay góc đạt tốc độ phản hồi $\le 16\text{ms}$ (60 FPS ổn định).
- **Memory & Resource:** Tiêu thụ RAM $\le 50\text{MB}$, CPU tĩnh = 0%, GPU tĩnh = 0%.
- **Architecture Invariants:** Tuân thủ 100% 12/12 Invariants trong `architecture_test.dart` và quy chuẩn Schema v2.1 của `AGENTS.md`.

---

## Success Criteria

- [ ] Toàn bộ emoji và tên "NoteRenderer" bị xóa sạch 100% khỏi giao diện plugin và SVG.
- [ ] Plugin hiển thị dạng thanh Dock cố định tone sáng academic thanh lịch.
- [ ] Đối tượng trên bảng hoạt động chuẩn Canva: Click chọn mới hiện 8 chốt co giãn + cuống xoay + thanh Floating Bar; click ngoài thì ẩn viền.
- [ ] Kéo điểm cực trị trực tiếp trên bảng phấn làm đồ thị biến dạng và công thức thay đổi theo thời gian thực (60 FPS).
- [ ] Gõ công thức trong ô nhập không bị giật, lỗi caret hay mất nét.
- [ ] `node scripts/validate_plugins.mjs` và `node scripts/run_architecture_check.mjs` đạt 100% PASS.

---

## Out of Scope

- Bổ sung hệ tọa độ 3D không gian $Oxyz$ tự do (thuộc bản phát hành tương lai).
- Nhận diện chữ viết tay công thức Toán từ AI OCR.

---

## Assumptions

- Thao tác kéo nắn điểm cực trị áp dụng cho các họ hàm số THPT chính (Bậc 3, Trùng phương, Nhất biến, Parabol bậc 2).
- Giáo viên tương tác bằng cả chuột máy tính lẫn màn hình cảm ứng tương tác phòng học thông minh.

