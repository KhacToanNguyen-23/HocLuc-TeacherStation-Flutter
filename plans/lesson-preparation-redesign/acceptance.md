# Nghiệm thu — DRAFT

Tất cả case dưới đây: NOT RUN. Đây là tiêu chí tương lai, không phải kết quả kiểm thử.

Đây là trạng thái nghiệm thu thủ công đầu-cuối. Code và kiểm thử tự động đã được bổ sung sau xác nhận triển khai; bằng chứng CI/automated được ghi riêng trong plan.md, không tự chuyển các case cần receiver/tài khoản/giáo viên thật thành PASS.

| ID | Luồng | Kết quả bắt buộc |
|---|---|---|
| A01 | Tạo bài một phần chỉ tên/nội dung | Lưu/mở lại thành công, không ép mục tiêu/thời lượng |
| A02 | Tạo bài 45 phút theo kịch bản A | Dàn ý/tổng thời gian/tài liệu đúng; title chung một lần |
| A03 | Biến thể lớp bài 90 phút | Bản lớp độc lập, có nguồn gốc bài gốc |
| A04 | Hai PDF riêng mỗi file note trang 3; cùng PDF dùng hai phần; pin/reset | Không cần soạn văn bản, context file/phần đúng, note phần rồi note trang không ghi đè; global fallback có nhãn; pin/reset đúng |
| A05 | Reorder/xóa/undo phần và trang; thay PDF khác fingerprint | Note theo ID/locator đúng; xóa có xử lý orphan, replacement cần remap, không gán sai |
| A06 | Vào bảng/thoát/mở lại 20 vòng không edit | Không lỗi Bài chưa lưu, không tăng revision vô nghĩa |
| A07 | 20 vòng bảng có edit rồi save | Nét viết, trang, notes và prep đều còn |
| A08 | Edit bảng rồi yêu cầu thoát, chọn tiếp tục hoặc bỏ edit | Cả hai lựa chọn đúng; bỏ chỉ bỏ thay đổi chưa lưu |
| A09 | 401 khi load ban đầu | Không hiện saved/blank overwritable; recover session đúng, không ghi đè bản cũ |
| A10 | Save bị 401/500/time-out | Nội dung còn, saved không giả; retry có kết quả rõ |
| A11 | Mất mạng, sửa rồi khởi động lại | Local recovery hiện rõ, không báo đã lên server, phục hồi đầy đủ |
| A12 | Đăng xuất A rồi đăng nhập B | Không thấy/đồng bộ nháp private của A vào B |
| A13 | Board save và prep save xen kẽ, cùng base revision | Cả hai scope tồn tại hoặc conflict giải được; không last-write-wins mất dữ liệu |
| A14 | Migration bài cũ chạy hai lần | Backup giữ, IDs giữ, lần hai không đổi; ambiguous notes được báo |
| A15 | Notes tự theo trang + ghim + reset; chọn phần để edit | Đúng actual output board/PDF, editor selection không đổi audience, ghim thấy rõ, reset về output hiện tại |
| A16 | Preview hai phía với notes/đáp án; dạy lại 3 lần | Học sinh preview không có; giáo viên có theo policy; canonical không đổi, không nhân generated pages |
| A17 | Receiver Google Meet thật, đổi trang/reconnect/source | Học sinh thật không thấy notes/đáp án; unknown source fail closed |
| A18 | Chọn chia sẻ cả desktop | Không quảng cáo privacy; bật bảo vệ theo policy, không giả pass A17 |
| A19 | Xuất hai PDF khi Python/API/speech đều tắt | Java PDF vẫn chạy; student không notes/đáp án, teacher có đúng mapping |
| A20 | Template trường/khoa thiếu trường + preview | Báo trường thiếu, mapping đúng, không mất nội dung |
| A21 | Chèn nhóm câu hỏi đã duyệt rồi reuse phần | Context/group giữ, đáp án private, provenance rõ |
| A22 | Classroom sandbox publish/retry | Đúng lớp/tệp student, có xác nhận API, không đăng trùng; lỗi auth phục hồi |
| A23 | Không AI/model; sau đó có AI có consent | Core vẫn dùng được; AI chỉ draft, lỗi không phá bài; không tự upload notes |
| A24 | Reflection/revision và DOCX compatibility (nếu bật P2) | Restore có diff; DOCX text sửa được và cảnh báo fidelity; corpus pass trước enable |

## Usability gate

Mời 5–8 giáo viên thật, bao gồm phổ thông và đại học. Chạy A02/A04/A15 và tìm/xuất bài mà không hướng dẫn từng nút. Mục tiêu ít nhất 80% lượt workflow hoàn tất không trợ giúp; ít nhất 4/5 người đầu tiên xác định đúng nội dung nào học sinh thấy. Ghi số lỗi, nơi dừng, assistance, mất dữ liệu, hiểu nhầm audience. Mẫu nhỏ chỉ định hướng cải tiến, không suy rộng tỷ lệ toàn bộ giáo viên.

Đo baseline thời gian trên bản hiện tại và quy trình giáo viên đang dùng, cùng dữ liệu/thiết bị; so với prototype và bản mới. Chưa đặt hoặc tuyên bố phần trăm tiết kiệm thời gian khi chưa có baseline. P1 privacy/data-loss lỗi bất kỳ đều chặn release, kể cả đạt usability threshold.

## Bằng chứng và CI

Lưu version/commit, dữ liệu fixture không chứa thông tin thật, log trạng thái/revision đã redact, kết quả automatable và video/screenshot receiver có consent. Chạy plugin validator, architecture gate, flutter analyze 0 errors/warnings, relevant frontend/backend regression và Windows/Web build theo AGENTS. CI pass không thay thế A17/A22/usability. Từng case có PASS/FAIL/BLOCKED cùng lý do, không đổi thành PASS chỉ vì test dependency chưa có.
