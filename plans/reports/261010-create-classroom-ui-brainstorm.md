# Brainstorm: UI Tạo Lớp Học & Tự Động Sinh Link Google Meet (1-Click Action Flow)

**Date:** 2026-10-10

## Ideas Explored
1. **Form tạo lớp đầy đủ:** Nhập tên lớp, chọn khối lớp, môn học rồi mới sinh link. (Đã loại bỏ vì rườm rà, làm chậm thao tác của giáo viên khi cần vào dạy nhanh).
2. **Tự động stream ngay khi tạo:** Ngay khi Meet tạo xong thì phát sóng màn hình luôn. (Đã loại bỏ theo phản hồi của người dùng: giáo viên cần quyền kiểm soát bật/tắt stream khi đã chuẩn bị xong giáo án).
3. **1-Click Tạo lớp & UI Hành động (Được chọn):** Nút "Tạo lớp học" nằm ở thanh trên cùng (TopBar). Bấm là tự sinh link Google Meet ngầm, hiển thị Dialog với link & nút Copy gửi học sinh. Giáo viên vào lớp và chỉ khi bấm "Bắt đầu dạy" / bật ON thì mới bắt đầu stream bảng trắng lên Meet.

## User's Direction
- Nút "Tạo lớp học" nằm ngay trên thanh trên cùng (TopBar).
- Tối giản: Bấm tạo là có link ngay, không cần chọn lớp mấy hay điền biểu mẫu phức tạp.
- Khi vào lớp: Có nút "Bắt đầu dạy" (hoặc công tắc On/Off) để giáo viên chủ động cho phép stream hình ảnh bảng trắng khi đã sẵn sàng.

## Open Questions
- Khi giáo viên tạo lớp mới trong khi lớp cũ đang diễn ra: Cần xác nhận đóng lớp cũ trước khi tạo lớp mới.

## Risks
- WebView2 tạo link ngầm phụ thuộc vào tốc độ mạng đến Google Meet (cần spinner và trạng thái rõ ràng nếu mạng lag).
- Tránh việc giáo viên quên bấm "Bắt đầu dạy" (cần badge cảnh báo trực quan: "Chưa phát sóng - Học sinh chưa thấy bảng").
