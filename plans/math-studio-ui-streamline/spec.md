# Spec: Tinh gọn Bố cục Math Studio (Hướng 2: Accordion Nâng Cao)

**Date:** 2026-10-26  
**Status:** Ready  

---

## Problem Statement
Cột bên trái của hộp thoại Math Studio bị rối mắt bởi 5 khối thẻ dàn trải và xuất hiện thanh cuộn ngang/dọc xấu xí do cụm Khung nhìn bị tràn. Cần tái cấu trúc cột trái: hiển thị trực diện 2 thẻ cốt lõi (HÀM SỐ & ĐIỂM), gom các mục phụ (Vật thể tròn xoay, Khung nhìn, Miền nghiệm) vào khối Accordion "Tùy chọn nâng cao" thu gọn mặc định, đồng thời tinh chỉnh Header để hiển thị trọn vẹn các tab.

---

## User Stories

- **[P1]** Là một giáo viên dạy toán, tôi muốn mở hộp thoại là thấy ngay ô nhập Hàm số và nút ĐIỂM (Cực trị, Giao trục) gọn gàng, không bị thanh cuộn làm rối mắt để có thể nhập và vẽ đồ thị tức thì.  
  *Accepted when:* Cột trái hiển thị vừa vặn trong chiều cao cửa sổ mà không sinh ra thanh cuộn ngang hay thanh cuộn dọc không mong muốn ở trạng thái mặc định.

- **[P1]** Là một giáo viên, tôi muốn thanh cuộn ngang ở cụm "KHUNG NHÌN" biến mất hoàn toàn, các ô nhập $x$ từ/đến và $y$ từ/đến co giãn vừa vặn với kích thước cột 380px.  
  *Accepted when:* `overflow-x` tại cột trái là `hidden`, các ô nhập liệu co giãn linh hoạt theo tỷ lệ phần trăm hoặc CSS grid.

- **[P2]** Là một giáo viên dạy bài Tích phân khối tròn xoay lớp 12, tôi muốn bấm mở "Tùy chọn nâng cao ▾" để kích hoạt mô hình tròn xoay hoặc chỉnh khoảng cách vạch tọa độ khi cần.  
  *Accepted when:* Bấm vào thanh tiêu đề "Tùy chọn nâng cao ▾" sẽ toggle hiển thị/thu gọn khối cài đặt nâng cao mượt mà.

- **[P2]** Là một giáo viên, tôi muốn nhìn thấy rõ đầy đủ cả 4 tab trên thanh tiêu đề (`[Đồ thị]`, `[Bảng biến thiên]`, `[Hình 3D SGK]`, `[Tích phân]`) mà không bị khuất mép phải.  
  *Accepted when:* Thanh tab header căn chỉnh gọn gàng, font chữ và padding tối ưu để không tràn viền.

- **[P3]** *(Out of scope)*: Tính năng giải và tô màu miền nghiệm hệ bất phương trình bậc nhất hai ẩn (sẽ thực hiện trong gói tính năng riêng).

---

## Functional Requirements

1. **FR-01 (Cấu trúc cột trái cốt lõi):** Cột trái gồm:
   - Thẻ 1: **HÀM SỐ** (Swatch chọn màu, tiền tố $y=$, ô nhập công thức, nút xóa `✕`, nút `Giới hạn [a, b]`).
   - Thẻ 2: **ĐIỂM** (Nút chính `+ Thêm điểm`, các nút pill `Giao Ox`, `Giao Oy`, `Cực trị`, và hàng tọa độ số khi bật cực trị).
2. **FR-02 (Khối Accordion Tùy chọn nâng cao):**
   - Tiêu đề: `Tùy chọn nâng cao ▾` (có icon mũi tên xoay khi đóng/mở).
   - Trạng thái mặc định: Thu gọn (`collapsed`).
   - Nội dung bên trong:
     - Dòng bật/tắt **Vật thể tròn xoay quanh Ox**.
     - Cụm **Khung nhìn thủ công** được thiết kế lại dạng grid 2 cột cân đối:
       - Hàng 1: $x \text{ từ}$ `[-6]` $\to$ $x \text{ đến}$ `[6]`
       - Hàng 2: $y \text{ từ}$ `[-4.1]` $\to$ $y \text{ đến}$ `[4.1]`
       - Hàng 3: Bước chia $x$ `[2]` & Bước chia $y$ `[2]`
     - Dòng tùy chọn **Miền nghiệm (Hệ BPT)** *(đang hoàn thiện)*.
3. **FR-03 (Header tabs tối ưu):**
   - Điều chỉnh `.mode-tab-nav` và `.mode-tab` với padding hợp lý (`3px 8px`, `font-size: 11.5px`) để 4 tab nằm trọn trong thanh Header, không bao giờ bị cắt cụt.
4. **FR-04 (Triệt tiêu thanh cuộn ngang):**
   - Thiết lập CSS chặt chẽ: `overflow-x: hidden`, loại bỏ hoàn toàn thanh cuộn ngang dưới chân cột điều khiển.

---

## Non-Functional Requirements

- **Giao diện sạch sẽ:** Đạt độ thoáng chuẩn thiết kế sư phạm của HocLuc Teacher Station, không còn cảm giác nhồi nhét.
- **Tương thích:** Tương thích 100% với các logic toán học sẵn có (`parseAndAnalyze`, `curve_manipulator`, `revolution_solid_plotter`).

---

## Success Criteria

- [ ] Không xuất hiện thanh cuộn ngang (`overflow-x`) ở cột trái dưới mọi trường hợp.
- [ ] Ở trạng thái mặc định, toàn bộ cột trái hiển thị trọn vẹn trong chiều cao 620px mà không bị cuộn dọc.
- [ ] Cả 4 tab trên thanh tiêu đề hiển thị trọn vẹn 100%, không bị khuất mép phải.
- [ ] Nút `Tùy chọn nâng cao ▾` đóng/mở mượt mà, lưu giữ trạng thái bật/tắt của khối tròn xoay.
- [ ] Bộ test kiến trúc (`node scripts/run_architecture_check.mjs`) và kiểm tra plugin (`node scripts/validate_plugins.mjs`) đạt 100% PASS.

---

## Out of Scope

- Không viết lại parser hay engine toán học.
- Chưa triển khai thuật toán tính miền nghiệm đa giác cho hệ bất phương trình.

