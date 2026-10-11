# Brainstorm: Teacher Station Broadcasting - Performance & Mirror Effect

**Date:** 2026-10-10

## Ideas Explored
- **Direction 1: Windows.Graphics.Capture (WGC/DXGI) API.** Khóa mục tiêu HWND của cửa sổ, chụp hình xuyên thấu các cửa sổ đè lên. Tích hợp dạng Microkernel Plugin.
- **Direction 2: Offscreen Rendering (Texture Extraction).** Can thiệp sâu vào Engine Flutter để lấy khung hình từ RAM.
- **Direction 3: Dual-Window Logic.** Tách làm 2 cửa sổ (1 điều khiển, 1 bảng trắng) để tránh quay nhầm.

## User's Direction
Người dùng chọn **Direction 1 (WGC API)** kết hợp với kiến trúc **Microkernel (Plugin Pattern)** để làm luận văn/ADR. Lý do:
- Đảm bảo tính lỏng lẻo (Loose Coupling): Plugin bắt hình hoạt động độc lập với Core App Flutter.
- Tính năng "Xuyên thấu": Giải quyết triệt để lỗi gương vô cực (Infinite Mirror - Zoom zoom) khi giáo viên vô tình kéo Google Meet đè lên App giảng dạy.
- Mượt mà hơn (Hardware Accelerated) so với phương pháp chụp tọa độ bằng phần mềm.

## Open Questions
- Tương thích HĐH: WGC bắt buộc Windows 10 (1803+) hoặc Windows 11. Cần đảm bảo môi trường giáo viên đáp ứng được.

## Risks
- **OS Compatibility:** Sẽ bị lỗi màn hình đen nếu chạy trên Windows 7 hoặc Windows 8.
- **DirectComposition / WinUI 3:** WGC xử lý tốt, nhưng cần lưu ý khi viết mã C++ để không bị block bởi các quyền bảo mật màn hình.
