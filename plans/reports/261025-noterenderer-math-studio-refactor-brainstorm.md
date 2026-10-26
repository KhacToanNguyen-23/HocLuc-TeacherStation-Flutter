# Brainstorm Report: Refactor Math Studio theo chuẩn UI/UX NoteRenderer

**Ngày:** 2026-10-25  
**Chủ đề:** Tái cấu trúc Math Studio Plugin thành Nền tảng Toán học Trực quan Bản xứ (Native Object) chuẩn 100% UI/UX NoteRenderer (Thầy Phạm Minh Tuấn) với Động cơ Vector 2.5D Siêu Nhẹ  
**Trạng thái:** Đồng thuận Kiến trúc (Consensus Achieved)

---

## 1. Vấn đề & Bối cảnh Hiện tại

- **Hạn chế của phiên bản cũ:** Plugin Math Studio hiện tại vẫn mang tư duy "cửa sổ con / popup bên ngoài ghim một tấm ảnh/SVG thụ động lên bảng". Trải nghiệm này rời rạc, làm đứt gãy mạch giảng dạy của giáo viên trên bảng phấn và chưa khai phóng được sức mạnh sư phạm trực quan.
- **Mục tiêu người dùng:** Yêu cầu nền tảng triển khai phải sở hữu **toàn bộ cốt lõi UI/UX của NoteRenderer** (phần mềm chuyên dụng của thầy Phạm Minh Tuấn):
  1. Đồ thị và hình vẽ toán học là **đối tượng tương tác bản xứ (First-class Object)** trực tiếp trên mặt bảng phấn, nền 100% trong suốt hòa vào ô ly caro bảng.
  2. Khung **Bounding Box nét đứt đặc trưng** với tay nắm xoay ở đỉnh giữa, 4 tay nắm vuông ở 4 góc để co giãn tỷ lệ tự do.
  3. **Thanh công cụ ngữ cảnh nổi (Floating Context Bar)** ngay trên đỉnh: `[ ⟳ Phát quay ]`, `[ Góc nhìn: Sách GK | Trước | Trên | Bên | Xoay 3D ]`, `[ ✎ Sửa ]`, `[ ⧉ Nhân bản ]`, `[ 🗑 Xóa ]`.
  4. Tính năng "ăn tiền" nhất: **[ ⟳ Phát quay ] (Solid of Revolution)** — miền diện tích tích phân $S$ tự động quay tròn quanh trục $Ox$, vẽ các đường elip chiều sâu tạo thành vật thể tròn xoay 3D (như chiếc bình hoa, khối nón, lăng trụ) chuẩn SGK lớp 12.
  5. **Kéo nắn đồ thị 2 chiều:** Kéo điểm cực trị / đỉnh / tiệm cận thì hệ số trong công thức nhảy số tương ứng theo thời gian thực.
  6. **Độ mượt & Nhẹ máy (Zero-Bloat Invariant):** Không dùng các framework cồng kềnh (loại bỏ React/Mafs), sử dụng thuật toán chiếu trục đo Vector 2.5D để đảm bảo máy tính giáo viên và màn hình tương tác cảm ứng chạy êm ru, 60fps, RAM ăn < 15MB.

---

## 2. Các hướng giải pháp đã đánh giá

| Phương án | Kiến trúc | Ưu điểm | Nhược điểm / Rủi ro | Đánh giá |
| :--- | :--- | :--- | :--- | :--- |
| **A. Mafs + React Bundle** | Đưa React và thư viện Mafs vào Webview | Đồ họa phẳng đẹp, có sẵn component SVG | Bundle nặng (+150KB runtime), ngốn 200MB RAM cho Virtual DOM, máy giáo viên dễ nóng và giật khi vẽ nét phấn | **LOẠI BỎ** (Không phù hợp môi trường trường học) |
| **B. Three.js Full 3D** | Render toàn bộ đồ thị qua WebGL Canvas 3D | Xoay 3D không gian tự do | GPU onboard Intel HD/UHD chạy quạt liên tục nếu có render loop, khó làm chữ LaTeX sắc nét và mờ lưới bảng | **GIỮ CHẾ ĐỘ DỰ PHÒNG** (Chỉ dùng on-demand cho Hình học 3D phức tạp) |
| **C. Pure Vector 2.5D Engine (NoteRenderer Blueprint)** | Hình học họa hình chiếu trục đo (Axonometric) + SVG Elip + Flutter Native Bounding Box | **Chuẩn xác 100% NoteRenderer**, RAM < 15MB, GPU 0%, chữ sắc nét vô cực, tương thích hoàn hảo mọi bảng cảm ứng | Cần tự xây dựng thuật toán sinh đường elip đồng mức và bề mặt quay | **CHỌN (KHUYẾN NGHỊ CAO NHẤT)** |

---

## 3. Bản đồ UI/UX & Luồng Tương tác Sư phạm

```
       [ ⟳ Phát quay ] [ Góc nhìn: SGK | Trước | Trên | Bên | Xoay 3D ] [ ✎ Sửa ] [ ❐ Nhân bản ] [ 🗑 Xóa ]
        ─────────────────────────────── Floating Context Bar ─────────────────────────────────
       ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐   ▲ (Tay nắm xoay)
       │ y = 1.5 + sin(x) (Nhãn công thức tương tác góc trái)                               │   │
       │                                                                                    │
       │                    ╭────────────────────────╮                                      │
       │                   ╱                          ╲                                     │
       │          ┌─────╱────────────────────────────────╲─────┐                            │
       │          │    │         Miền tích phân S        │     │  (Khối tròn xoay 3D         │
       │ ─────────┼────┼─────────────────────────────────┼─────┼────────────────────────────│─── Trục Ox
       │          │    │      quay quanh trục Ox         │     │   với các elip chiều sâu)  │
       │          └─────╲────────────────────────────────╱─────┘                            │
       │                   ╲                          ╱                                     │
       │                    ╰────────────────────────╯                                      │
       └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘ ──■ (Tay nắm co giãn)
```

1. **Native Object on Board:** Đối tượng nằm ngay trên mặt bảng phấn, nền trong suốt.
2. **NoteRenderer Bounding Box:** Viền nét đứt màu nâu cam / trắng phấn, 4 góc có 4 chốt vuông co giãn tự do, đỉnh giữa có chốt xoay góc.
3. **Formula Tag:** Góc trên bên trái hiển thị công thức, bấm vào gõ sửa tức thì.
4. **Floating Context Bar:** Thanh nút tròn mềm mại bám sát trên đầu Bounding Box.
5. **[Phát quay]:** Tạo chuyển động xoay quanh $Ox$ biến hình phẳng thành chiếc bình 3D sinh động.

---

## 4. Kế hoạch Handoff

- Chuyển tiếp toàn bộ nội dung sang tài liệu đặc tả `plans/math-studio-plugin/spec.md`.
- Lập kế hoạch thực thi chi tiết 4 giai đoạn trong `plans/math-studio-plugin/plan.md`.
- Sẵn sàng kích hoạt `$bb-cook` triển khai.

