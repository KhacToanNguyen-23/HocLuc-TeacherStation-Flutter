# Brainstorm: Math Studio Editorial UI & Zero-Latency UX Redesign

**Date:** 2026-10-27  
**Topic:** Tái cấu trúc giao diện phân cấp sư phạm (Editorial Inspector 32:68) và tối ưu độ trễ tương tác (Zero-Lag UX).

---

## Ideas Explored

1. **Floating Island / Single Canvas Mode (Bác bỏ)**:
   - Đưa mọi nút điều khiển thành thanh nổi Dynamic Island đè lên đồ thị.
   - *Đánh giá*: Giải phóng diện tích nhưng thao tác nhập hàm và theo dõi chi tiết đạo hàm/cực trị bị che khuất đường cong toán học, không tiện cho giáo viên vừa giảng vừa nhìn số liệu.

2. **Bố cục 2 Cột cũ (35% : 65%) với Card lồng Card (Hiện trạng - Bác bỏ)**:
   - Input tách rời preview xám, nhiều hộp viền dày lồng nhau, khoảng trắng đáy trống hoác, thiếu thông tin sư phạm cốt lõi (đồng biến/nghịch biến, tâm đối xứng).

3. **Bố cục 2 Cột Tỷ lệ Vàng (32% Editorial Inspector : 68% Live Canvas) - ĐƯỢC CHỌN**:
   - Khối nhập hàm Hero Formula Input thống nhất (loại bỏ ô xám thừa).
   - Tích hợp 4 trụ cột sư phạm SGK 2018: TXĐ & Đạo hàm, Chiều biến thiên ($\nearrow, \searrow$), Cực trị ($CĐ, CT$), Tiệm cận & Tâm đối xứng ($I$).
   - Hairline dividers thay cho Box-in-a-Box.
   - Tối ưu UX: JIT CAS Compiler + Zero-Destruction In-place Board Updates + Debounce thông minh < 80ms, phản hồi tương tác click điểm < 16ms.

---

## User's Direction

- **Bố cục**: Giữ dạng 2 cột (Split View), tái cấu trúc phân cấp thị giác hiện đại, thanh thoát, xóa bỏ cảm giác hộp lồng hộp vụn vặt và triệt tiêu khoảng trắng chết.
- **Hàm số**: Hợp nhất thành 1 khối nhập toán học cao cấp duy nhất (Hero Formula Block), hiển thị công thức rõ ràng bằng typography STIX Math.
- **Nội dung sư phạm**: Bổ sung đầy đủ 4 trụ cột sư phạm SGK GDPT 2018 (Khoảng đơn điệu $\nearrow, \searrow$, Cực trị, Tâm đối xứng / Điểm uốn $I$, Tiệm cận).
- **UX & Độ trễ**: Tối ưu triệt để độ trễ, loại bỏ hiện tượng giật lag hoặc quay tròn, tương tác mượt mà trong 1 khung hình (60fps).

---

## Open Questions

- Định dạng hiển thị khoảng đơn điệu: Thể hiện dạng chuẩn SGK Việt Nam `(-∞; -1) và (1; +∞)` với ký hiệu trực quan $\nearrow, \searrow$.
- Điểm uốn / Tâm đối xứng: Tự động giải $f''(x) = 0$ cho hàm bậc 3 và giao 2 tiệm cận cho hàm phân thức bậc 1/1, bậc 2/1.

---

## Risks

1. **Over-computation trong luồng gõ (Input lag)**: Nếu giải $f''(x)$ và khoảng đơn điệu trực tiếp trong từng phím gõ có thể gây trễ.
   *Giải pháp*: Dùng Micro-CAS JIT compiled evaluator phân tích trong < 3ms, áp dụng debounce 80ms cho việc dựng lại cây giải tích.
2. **Tràn dọc trên màn hình độ phân giải thấp**: Nếu cột trái có quá nhiều mục có thể bị cuộn.
   *Giải pháp*: Thiết kế thẻ co giãn linh hoạt (Semantic Sections với typography vi mô chuẩn 12-13px), tổng chiều cao vừa vặn trong 512px (khung 560px trừ 48px header).

