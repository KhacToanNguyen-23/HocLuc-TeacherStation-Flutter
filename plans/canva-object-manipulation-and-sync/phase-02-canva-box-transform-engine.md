# Phase 2: Canva BoxTransform Engine & Crash Elimination

**Objective:** Khắc phục triệt để lỗi assertion `shifted_box.dart: Failed assertion: line 111` trong Flutter, tách thanh công cụ nổi ra khỏi ma trận xoay, và xây dựng toán học chiếu toạ độ kéo co dãn 8 chốt chuẩn công nghiệp Canva/Figma.

---

## 1. Context & Root Cause
- **Lỗi `shifted_box.dart: Failed assertion: line 111`:**
  - `OverflowBox` nằm lồng bên trong `Transform.rotate` với `childParentData.offset` âm/lẻ.
  - Khi click/drag, `RenderTransform` áp dụng ma trận xoay nghịch đảo, dẫn đến kiểm tra `assert(transformed == position - childParentData.offset)` bị fail.
  - Khi assertion này bị ném ra, cây bắt cử chỉ (Gesture Arena) của Flutter bị hủy bỏ $\rightarrow$ người dùng chỉ tương tác được 1 lần rồi bị đơ hoàn toàn.
- **Thanh công cụ nổi xoay nghiêng ngả:**
  - Trong Canva / Figma, thanh công cụ (`[Ghim | Sửa | Xóa]`) **luôn nằm ngang phía trên** đối tượng để người dùng đọc và thao tác được, không bao giờ xoay tròn theo hình.

---

## 2. Implementation Steps

1. **Tách biệt thanh công cụ nổi ra ngoài `Transform.rotate` trong `frontend/lib/features/studio_board/presentation/board_sticker_card.dart`:**
   - Cấu trúc widget phân tầng rõ ràng:
     ```dart
     Stack(
       clipBehavior: Clip.none,
       children: [
         // Layer 1: Đối tượng xoay (Transform.rotate)
         Transform.rotate(
           angle: sticker.rotation,
           alignment: Alignment.center,
           child: Stack(
             clipBehavior: Clip.none,
             children: [
               // Bounding box + Content (SVG)
               // 8 Canva Handles (4 góc + 4 cạnh)
               // Rotation Stem & Handle (Chốt xoay trên đỉnh)
             ],
           ),
         ),
         // Layer 2: Canva Floating Action Bar (LUÔN NẰM NGANG, KHÔNG XOAY)
         if (isSelected)
           Positioned(
             top: 0,
             left: 0,
             right: 0,
             child: Center(
               child: _buildFloatingActionBar(),
             ),
           ),
       ],
     )
     ```
   - Tuyệt đối không dùng `OverflowBox` bên trong `Transform.rotate`.

2. **Thuật toán chiếu Delta chuột qua ma trận nghịch đảo góc xoay $R(-\theta)$:**
   - Trong `_handleCornerResize` và `_handleEdgeResize`:
     ```dart
     final cosTheta = math.cos(-sticker.rotation);
     final sinTheta = math.sin(-sticker.rotation);
     final localDx = (details.delta.dx / parentW) * cosTheta - (details.delta.dy / parentH) * sinTheta;
     final localDy = (details.delta.dx / parentW) * sinTheta + (details.delta.dy / parentH) * cosTheta;
     ```
   - **Kéo 4 góc:** Khóa tỉ lệ (Aspect Ratio Lock), giữ nguyên vị trí chốt đối diện (Opposite Anchor Pinning).
   - **Kéo 4 cạnh:** Co dãn 1 chiều độc lập (cạnh trái/phải dãn `width`, cạnh trên/dưới dãn `height`).
   - Giới hạn kích thước tối thiểu (clamp) không cho co nhỏ dưới $0.05$ để không bị đảo ngược hình.

3. **Vòng đời tương tác không giới hạn (Continuous Selection Lifecycle):**
   - Trong `interactive_chalkboard.dart`: Đảm bảo khi bấm ra ngoài bảng phấn thì `widget.studio.selectSticker(null)` deselect ngay lập tức; khi click lại vào bất kỳ sticker nào thì sticker đó re-select lập tức.
   - Thao tác kéo, xoay, click ngoài, click lại có thể thực hiện liên tục vô hạn lần mà không bao giờ bị đơ hay ném assertion error.

---

## 3. Acceptance Criteria
- [ ] Không còn bất kỳ lỗi nào liên quan tới `shifted_box.dart: Failed assertion: line 111` trong Flutter console.
- [ ] Thanh công cụ nổi luôn nằm ngang chuẩn Canva, dễ đọc và dễ bấm ở mọi góc xoay của đối tượng.
- [ ] Thao tác kéo 4 góc phóng to/thu nhỏ đồng dạng mượt mà; kéo 4 cạnh co dãn 1 chiều chính xác ở mọi góc xoay $0^\circ \to 360^\circ$.
- [ ] Bấm ra ngoài bảng phấn ẩn viền cam và 8 chốt; bấm lại vào sticker kích hoạt lại bình thường, lặp lại nhiều lần không bị lỗi.

