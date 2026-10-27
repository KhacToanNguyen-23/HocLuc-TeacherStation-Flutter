# Brainstorm: Tối Ưu Tương Tác & Khử Mờ Đồ Thị JSXGraph Chuẩn Sư Phạm

**Date:** 2026-10-26

## Ideas Explored
1. **Phương án 1 (Full Reactive JSXGraph):** Giữ engine JSXGraph nhưng tái cấu trúc cơ chế reactive: loại bỏ việc destroy/rebuild board khi kéo chuột, tắt vạch phụ li ti `minorTicks: 0` để trục số nét căng, mở khóa kéo cực trị 2 chiều và tính diện tích hình phẳng SGK $S = \int |f(x)|dx$.
2. **Phương án 2 (Tách riêng Tab Đồ thị & Tab Tích phân):** Tab Đồ thị chỉ khảo sát cực trị, giao điểm; Tab Tích phân mới hiển thị mút cận $a, b$ và diện tích.
3. **Phương án 3 (Quay lại Canvas/SVG nội bộ):** Viết lại bộ bắt sự kiện và render SVG thủ công.

## User's Direction
Người dùng chọn **Phương án 1 (Full Reactive JSXGraph)**:
- Khử mờ tuyệt đối cho trục số $Ox, Oy$ (chữ số rõ ràng, dứt khoát, không bị răng cưa).
- Sửa lỗi kéo thả: Mút tích phân $a, b$ và điểm cực trị kéo mượt mà, không bị giật hay desync giữa đồ thị và ô nhập liệu.
- Chuẩn hóa tích phân SGK: Ẩn số tích phân đại số có dấu của thư viện, hiển thị chuẩn diện tích hình phẳng $S = \int_a^b |f(x)| dx$.

## Technical Root Causes Identified
1. **Trục Ox bị mờ:** JSXGraph tự động sinh ra 4-5 vạch phụ (`minorTicks`) giữa mỗi số nguyên làm trục trông như lược chải dày đặc, làm mờ chữ số.
2. **Kéo mút tích phân bị giật / mất đồng bộ:** Hàm `renderIntegralTable` đang destroy board (`freeBoard`) ngay trong lúc chuột đang rê, làm đứt event capture.
3. **Cực trị không di chuyển được:** Đang gán `fixed: true` cứng trên điểm cực trị.
4. **Tích phân bị sai giá trị:** JSXGraph mặc định vẽ tích phân có dấu ($\int f(x) dx$), trong khi bài toán SGK yêu cầu diện tích hình phẳng tuyệt đối ($S = \int |f(x)| dx$).

## Open Questions for Planning
- Khi kéo mút $a, b$, có nên tự động hít (magnetic snap) vào bước 0.5 để số ra đẹp như đề thi SGK không? (Có, snap 0.5 hoặc 0.25).
- Tần số cập nhật công thức khi kéo cực trị: Throttling 16ms (60 FPS) để mượt mà trên WebView2.

## Risks
- Xung đột event giữa panning/zooming của JSXGraph và event kéo điểm: Cần cấu hình `pan: false` khi hover vào điểm kéo.

