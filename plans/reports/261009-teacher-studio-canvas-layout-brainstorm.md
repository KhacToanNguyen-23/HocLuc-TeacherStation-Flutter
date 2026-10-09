# Brainstorm: Universal Whiteboard & PDF Split Studio Layout

**Date:** 2026-10-09

## Ideas Explored
- **Multi-Screen Navigation:** Mỗi chức năng (Bảng viết, PDF, Bảng câu hỏi) là một màn hình tách biệt hoàn toàn; chuyển màn hình qua thanh điều hướng bên. (Bị loại bỏ vì làm ngắt quãng sự chú ý của học sinh khi stream trên Google Meet/Zoom).
- **Floating Windows Overlay:** Bảng trắng là nền duy nhất, các tài liệu PDF và công cụ mở dưới dạng cửa sổ trôi nổi tự do (Floating Window/Dialog). (Bị loại bỏ vì khó kiểm soát không gian viết khi dạy học trên tỷ lệ 16:9).
- **Hybrid Ergonomic Split-View with Fullscreen Toggles (Được chọn):** Bảng viết ô li xanh đen làm Canvas trung tâm mặc định; hỗ trợ chia đôi (Split 50/50 hoặc 40/60) giữa PDF đề bài và Bảng ô li giải đề; phím tắt/nút 1-chạm F1 (Bảng Full), F2 (PDF Full), F3 (Split); các công cụ phụ (Camera PIP, Timer, Mục lục) nằm ở Floating Dock bo góc và Drawer trượt.

## User's Direction
Người dùng định hướng biến ứng dụng thành một Studio giảng dạy phổ quát (không chia môn cụ thể):
- **Bảng ô li xanh đen:** Nền xanh đen (Dark Slate #14221D) chống mỏi mắt cho học sinh và giáo viên, kẻ lưới ô li học sinh rõ nét, chuột rê trên bảng hiển thị dạng chấm sáng (Laser Pointer dot).
- **Tương tác PDF:** Hỗ trợ import PDF qua cả 2 cách (File Picker và Drag & Drop). Cho phép viết/vẽ đè trực tiếp lên trang PDF (Annotation mode) kèm lề làm nháp, nét vẽ được lưu và chuyển đổi riêng biệt theo từng trang PDF.
- **Bố cục 16:9 công thái học:** Mặc định Split View linh hoạt; phím tắt chuyển nhanh F1 (Toàn màn hình Bảng), F2 (Toàn màn hình PDF), F3 (Split View).
- **Công cụ phụ:** Camera PIP ghim góc trên phải bo tròn ($240 \times 135\text{ px}$); Timer nhỏ gọn cạnh trên; Bảng danh sách câu hỏi trượt dạng Drawer mép trái.

## Technical Selections
- **PDF Viewer Engine:** `pdfrx` (Engine Google PDFium, Apache-2.0) — render PDF bằng phần cứng cực nhanh, hỗ trợ cả Flutter Web và Windows Desktop, hỗ trợ gesture zoom/pan và tương thích tốt với tỷ lệ 16:9.
- **Interactive Freehand Drawing:** `Flutter CustomPainter` + `perfect_freehand` (MIT) — thuật toán vẽ nét bút tự nhiên với độ dày thay đổi theo tốc độ/áp lực, tạo cảm giác viết bảng chân thực như bút phấn thật.
- **File Picker & Drag-Drop:** `file_picker` + `desktop_drop`.

## Open Questions & Verification
- Tùy chọn xuất (Export) file PDF đã được ghi chú kèm trang bảng nháp sau buổi học.
- Tinh chỉnh tham số `thinning`, `smoothing`, `streamline` của `perfect_freehand` để phù hợp với nét viết bảng tiếng Việt.

## Risks
- Đảm bảo tỷ lệ khung hình $16:9$ cố định khi stream ra Virtual Camera để không bị méo hoặc đen viền (letterboxing).
- Quản lý hiệu năng bộ nhớ khi lưu trữ danh sách nét vẽ vector (strokes) trên nhiều trang PDF.
