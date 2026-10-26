# Spec: Nền tảng Toán học Trực quan NoteRenderer (Math Studio 2.0)

**Date:** 2026-10-25  
**Status:** Ready  
**Domain:** HocLuc Teacher Station — Studio Board & Math Studio Plugin  

---

## Problem Statement

Giáo viên dạy Toán THPT khi giảng bài Giải tích 12 (đồ thị hàm số, tích phân, thể tích khối tròn xoay) và Hình học không gian hiện phải chuyển đổi qua lại giữa nhiều phần mềm rời rạc hoặc sử dụng popup che khuất bảng phấn. Họ cần một công cụ **Toán học tương tác bản xứ (Native Object)** nằm trực tiếp trên mặt bảng phấn với 100% linh hồn UI/UX của **NoteRenderer**: Bounding Box nét đứt trực quan, thanh công cụ ngữ cảnh nổi trên đầu, tính năng "Phát quay" khối tròn xoay 3D tức thì, kéo nắn đồ thị 2 chiều, mà vẫn đảm bảo siêu nhẹ, mượt mà 60fps trên mọi máy tính và màn hình tương tác trường học.

---

## User Stories

### P1 — Must Have (Trọng tâm Cốt lõi NoteRenderer)

- **[P1-US01]** Là giáo viên Toán, tôi muốn đồ thị và bảng biến thiên khi đưa ra bảng phấn sẽ hiển thị dưới dạng **đối tượng bản xứ nền trong suốt (Zero-background Native Object)**, để nét vẽ và lưới tọa độ mờ hòa hợp tự nhiên với các ô ly phấn trên mặt bảng HocLuc.  
  *Accepted when:* Đồ thị hiển thị không có mảng nền trắng bệch, lưới tọa độ hiển thị mờ thanh lịch, nhìn rõ màu xanh ô ly của bảng phấn phía dưới.

- **[P1-US02]** Là giáo viên Toán, tôi muốn khi chọn vào đồ thị trên bảng phấn, một khung **Bounding Box nét đứt chuẩn NoteRenderer** xuất hiện bao quanh hình với tay nắm xoay ở đỉnh giữa và 4 tay nắm vuông ở 4 góc, để tôi có thể xoay và co giãn kích thước đồ thị tự do.  
  *Accepted when:* Kéo 4 góc thay đổi kích thước mượt mà không làm méo tỷ lệ; kéo tay nắm xoay ở đỉnh làm xoay góc hiển thị của đồ thị; nhấp ra ngoài bảng thì viền nét đứt và thanh công cụ ẩn đi.

- **[P1-US03]** Là giáo viên Toán, tôi muốn thanh **Floating Context Bar (Thanh công cụ ngữ cảnh nổi)** tự động lơ lửng ngay phía trên cạnh trên của Bounding Box với các nút: `[ ⟳ Phát quay ]`, `[ Góc nhìn: Sách GK | Trước | Trên | Bên | Xoay 3D ]`, `[ ✎ Sửa ]`, `[ ⧉ Nhân bản ]`, `[ 🗑 Xóa ]`.  
  *Accepted when:* Thanh công cụ di chuyển đồng bộ theo Bounding Box; các nút bấm có kích thước cảm ứng thân thiện (touch-friendly), hiệu ứng hover/active mềm mại.

- **[P1-US04]** Là giáo viên dạy Giải tích 12, tôi muốn khi bấm nút **`[ ⟳ Phát quay ]`**, miền diện tích tích phân $S$ phẳng lập tức **quay tròn quanh trục hoành $Ox$ (Solid of Revolution)**, tự động dựng các đường elip chiều sâu và dải màu gradient tạo thành **vật thể tròn xoay 3D (chiếc bình hoa, khối nón, khối trụ)** chuẩn SGK.  
  *Accepted when:* Bấm `[ ⟳ Phát quay ]`, hình phẳng chuyển động quay sinh động thành vật thể tròn xoay 3D với các đường elip tiết diện và trục đối xứng; bấm lại hoặc chọn góc nhìn đưa về đồ thị 2D ban đầu.

- **[P1-US05]** Là giáo viên Toán, tôi muốn nhãn công thức toán học (`y = ...`) hiển thị trực tiếp ở góc trên bên trái của Bounding Box, cho phép tôi chạm/click thẳng vào nhãn để gõ sửa công thức nhanh mà không cần mở lại hộp thoại cài đặt.  
  *Accepted when:* Nhấp vào nhãn công thức cho phép sửa nhanh chuỗi hàm số; nhấn Enter thì đồ thị, cực trị và bảng biến thiên tự động cập nhật ngay trên bảng.

- **[P1-US06]** Là giáo viên Toán, tôi muốn có thể dùng chuột hoặc bút cảm ứng cầm kéo trực tiếp các điểm cực trị, đỉnh parabol hoặc đường tiệm cận trên đồ thị để hệ số trong công thức tự động nhảy số theo thời gian thực (Interactive Curve Manipulation).  
  *Accepted when:* Kéo điểm cực đại/cực tiểu của hàm bậc 3 hoặc đỉnh parabol, đường cong biến dạng mượt mà và nhãn công thức hiển thị hệ số mới tức thì.

### P2 — Nice to Have (Mở rộng Không gian 3D & Nâng cao)

- **[P2-US07]** Là giáo viên Toán, tôi muốn khi chuyển đổi qua lại giữa các `[ Góc nhìn: Sách GK | Trước | Trên | Bên | Xoay 3D ]`, vật thể tròn xoay hoặc khối hình học 3D sẽ chuyển đổi góc chiếu trực giao (Orthographic projections) hoặc cho phép cầm bút xoay tự do 360 độ.  
  *Accepted when:* Chọn "Sách GK" hiển thị góc chiếu phối cảnh chuẩn SGK; chọn "Trước/Trên/Bên" hiển thị hình chiếu vuông góc; chọn "Xoay 3D" cho phép kéo chuột xoay vật thể.

- **[P2-US08]** Là giáo viên Toán, tôi muốn nút `[ ⧉ Nhân bản ]` trên Floating Context Bar tạo ra một bản sao đồ thị giống hệt ngay bên cạnh (offset nhẹ), để tôi có thể giảng bài toán so sánh tham số $m$ hoặc biến đổi đồ thị $y = |f(x)|$.  
  *Accepted when:* Bấm `[ ⧉ Nhân bản ]` tạo thêm 1 đối tượng độc lập trên bảng với đầy đủ Bounding Box riêng.

---

## Functional Requirements

- **FR-01 (Direct Chalkboard Rendering):** Nền tảng Studio Board hiển thị đối tượng Math Studio dạng vector SVG trong suốt, không có nền trắng hoặc bóng hộp đè lên bảng phấn.
- **FR-02 (NoteRenderer Bounding Box System):** Khung chọn bao gồm:
  - Đường viền nét đứt màu nâu cam đất (`#b45309` hoặc `#f59e0b` trên nền sáng, `#fde047` / trắng phấn trên bảng xanh).
  - 4 chốt vuông kích thước 10x10px tại 4 góc hỗ trợ resize 2 chiều.
  - 1 chốt tròn có cuống xoay (Rotation Stem) ở giữa cạnh trên hỗ trợ xoay góc $\theta$.
- **FR-03 (Floating Context Bar System):** Thanh công cụ bo tròn nổi lơ lửng cách mép trên Bounding Box 8px, gồm:
  - Nút `[ ⟳ Phát quay ]` (Icon quay + Text).
  - Nút `[ Góc nhìn: ... ]` dạng dropdown hoặc segment selector.
  - Nút `[ ✎ Sửa ]` kích hoạt inline editor hoặc mở sidebar tùy chỉnh.
  - Nút `[ ⧉ Nhân bản ]` duplicate đối tượng.
  - Nút `[ 🗑 Xóa ]` remove đối tượng khỏi trang bảng.
- **FR-04 (2.5D Solid of Revolution Engine):**
  - Thuật toán nhận hàm số $y = f(x)$ và đoạn tích phân $[a, b]$.
  - Tự động lấy mẫu bán kính $r(x) = |f(x)|$ tại các điểm mốc.
  - Vẽ đường cong đối xứng $y = -f(x)$ qua trục hoành $Ox$.
  - Dựng các đường elip tiết diện tại $x = a$, $x = b$, và tại các điểm cực trị/điểm uốn với bán trục lớn $r(x)$ và bán trục nhỏ $r(x) \times \sin(\alpha)$ (góc nghiêng trục đo).
  - Tô màu gradient lưới mờ (Wireframe mesh + Shaded volume) tạo hiệu ứng chiều sâu 3D chân thực.
- **FR-05 (Formula Direct Editing):** Nhãn công thức toán dạng badge tương tác ở góc trên bên trái khung đồ thị, hỗ trợ chỉnh sửa inline và đồng bộ ngược về bộ giải tích.
- **FR-06 (Zero Hardcoded Invariants):** Tuân thủ tuyệt đối quy tắc Rule 1 & Rule 2 của `AGENTS.md`: Host Flutter hoàn toàn trung lập (Microkernel Host), các hành vi tương tác mở rộng được đóng gói qua Host Bridge Protocol.

---

## Non-Functional Requirements

- **Performance (Zero-Bloat Invariant):**
  - Không tải React hay runtime nặng.
  - Bộ nhớ RAM tiêu thụ cho một đối tượng đồ thị trên bảng $\le 15$ MB.
  - Khung hình đạt tối thiểu 60 fps khi kéo thả, co giãn hoặc xoay trên máy Core i3 / Intel HD Graphics.
  - Tính năng "Phát quay" kết xuất hình ảnh trong $\le 50$ ms.
- **Pedagogical Aesthetics (Chuẩn Sư phạm SGK):**
  - Màu sắc, kiểu đường nét, mũi tên bảng biến thiên, trục tọa độ và elip khối tròn xoay tuân thủ 100% quy chuẩn trình bày SGK Toán Việt Nam (Chương trình GDPT 2018).
- **Usability (Thiết bị Cảm ứng & Máy chiếu):**
  - Mọi nút bấm và tay nắm có vùng chạm (touch target) tối thiểu 36x36 dp, hỗ trợ cảm ứng đa điểm, bút Stylus (bút thông minh) và chuột máy tính.

---

## Success Criteria

- [ ] Toàn bộ đồ thị khi xuất hiện trên bảng phấn có **nền trong suốt 100%**, lưới mờ hòa vào caro bảng.
- [ ] Bounding Box nét đứt xuất hiện khi click chọn đối tượng, có đủ 4 chốt góc và chốt xoay ở đỉnh.
- [ ] Floating Context Bar hiển thị đầy đủ 5 nút chức năng chuẩn NoteRenderer.
- [ ] Bấm nút **[ ⟳ Phát quay ]** tạo ngay lập tức mô hình chiếc bình/khối tròn xoay 3D với các đường elip chiều sâu mượt mà trong $< 50$ ms.
- [ ] Bấm vào nhãn công thức toán học ở góc trên bên trái cho phép gõ sửa hàm số và đồ thị cập nhật ngay.
- [ ] `flutter test test/architecture_test.dart` tiếp tục đạt **12/12 Invariants PASS 100%**.
- [ ] `node scripts/validate_plugins.mjs` đạt **0 lỗi, 100% in sync**.
- [ ] `flutter analyze --no-fatal-infos` đạt **0 errors, 0 warnings**.

---

## Out of Scope

- Dựng mô hình 3D đa giác phức tạp (OBJ/GLTF mesh phức tạp từ bên thứ ba) — giữ trọng tâm thuần túy cho giải tích và hình học SGK THPT.
- Nhận dạng chữ viết tay AI trực tiếp từ nét bút vẽ trên bảng (đã có mô-đun riêng).

---

## Assumptions

1. Thầy cô tương tác trên bảng phấn chủ yếu bằng chuột hoặc bút cảm ứng trên màn hình thông minh / máy tính bảng.
2. Các khối tròn xoay chủ yếu quay quanh trục hoành $Ox$ theo chuẩn chương trình Toán 12 SGK (hỗ trợ thêm tùy chọn quay quanh $Oy$).

