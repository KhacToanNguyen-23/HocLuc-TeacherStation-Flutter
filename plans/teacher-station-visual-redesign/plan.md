# Mộc Teaching Studio — Kế hoạch thay đổi diện mạo

Ngày: 2026-10-15. Trạng thái: người dùng đã duyệt, đã triển khai. Kết quả và giới hạn kiểm chứng tại [implementation.md](implementation.md).

## 1. Phạm vi đã thống nhất

Thay đổi diện mạo toàn bộ ứng dụng desktop cho giáo viên: đăng nhập, dashboard, soạn bài, sảnh vào lớp, studio, đề thi và các panel/dialog liên quan. Mục tiêu là cảm giác đồng hành, rõ ràng, đáng tin cậy; giáo viên dễ tập trung vào bài dạy và học liệu.

Yêu cầu mới nhất thay thế đề xuất tái cấu trúc trước đó: giữ nguyên bố cục, điều hướng, vị trí công cụ và luồng thao tác hiện tại. Các thay đổi spacing từ lượt làm việc trước được xem là một phần của hiện trạng; kế hoạch này không tiếp tục tái bố trí chúng.

Hỗ trợ desktop với chuột, bàn phím và bút viết. Chưa có phạm vi điện thoại. Độ hoàn thiện hướng tới triển khai thực tế; đây là kế hoạch thiết kế, không phải yêu cầu xây dựng prototype hay tính năng mới.

## 2. Hành động chính của giáo viên

Chuẩn bị học liệu rồi sử dụng chúng khi giảng dạy hoặc ôn thi. Thứ bậc thị giác phải giúp nhận ra tác vụ chính, công cụ đang chọn và trạng thái buổi học mà không cần học lại vị trí thao tác.

## 3. Hướng thị giác đề xuất

- Chiến lược màu: restrained. Nền trung tính sáng, bề mặt trắng, chữ slate; xanh dương tập trung ở hành động chính và lựa chọn hiện tại.
- Bối cảnh thiết kế: giáo viên làm việc lâu trên laptop Windows, đọc tài liệu và viết bài, cần nhận biết trạng thái nhanh trong lúc điều hành lớp. Giữ theme sáng đang dùng làm nền tảng; xác nhận bằng bản chụp thực tế thay vì giả định màu tối sẽ hợp studio hơn.
- Giữ Manrope cho UI và Literata tại dấu nhận diện hiện có; chỉnh cấp độ chữ, độ đậm và độ tương phản một cách có kiểm soát.
- Dùng icon Material hiện có với cách chọn nét và trạng thái nhất quán; không thay biểu tượng nhận diện sản phẩm hoặc logo Google Meet bằng các hình sinh thử.
- Bề mặt phẳng, đường phân cách rõ, độ nổi chỉ dành cho thành phần thực sự phủ lên nội dung. Bo góc có phân cấp theo loại thành phần thay vì bo lớn trên mọi khối.
- Tính giáo dục đến từ học liệu, công cụ viết và khả năng đọc. Không mặc định thêm màu xanh lá, hình sách/bút trang trí, biểu tượng lấp lánh hoặc minh họa ở mọi trạng thái.

Neo tham chiếu là chính các màn hình và tài nguyên của dự án. Người dùng không chọn sản phẩm bên ngoài làm mẫu. Ba ảnh A/B/C đã thử làm thay đổi cấu trúc nên không được dùng làm bố cục triển khai; chữ, công thức, logo và trạng thái trong ảnh không phải đặc tả.

## 4. Ranh giới thay đổi

Được chỉnh màu vai trò, độ tương phản, font weight, icon tương đương về ý nghĩa, viền, bo góc, bóng đổ và phản hồi hover/focus/pressed. Giữ kích thước icon và ô chứa để tránh dịch chuyển nội dung.

Giữ nguyên khung trang, cột, thứ tự thẻ, tab, toolbar, vị trí panel, kích thước canvas, cơ chế overlay và các breakpoint hiện có. Không thêm sidebar, filmstrip, chế độ chia đôi mới hoặc nút đổi theme. Không thay thuật toán bảng/PDF, ghi nét bút, chia sẻ hình ảnh, quyền tài khoản, thao tác Google Meet hoặc hợp đồng dữ liệu.

Kích thước chữ, line-height và padding ban đầu giữ theo hiện trạng. Nếu cần sửa để đọc được hoặc tránh lỗi, ghi nhận riêng tác động về hình học trước khi đưa vào phạm vi. Không rút gọn nhãn chức năng chỉ để vừa kiểu dáng mới.

## 5. Kế hoạch theo bề mặt

| Bề mặt | Thay đổi diện mạo | Bố cục cần đối chiếu |
| --- | --- | --- |
| Đăng nhập/đăng ký | Tiết chế gradient và bóng rộng; thống nhất input, nút, tab và trạng thái lỗi. Giữ tài nguyên minh họa hiện có trong lượt đầu. | Khung đăng nhập, hai vùng minh họa/form và vị trí các phương thức đăng nhập. |
| Dashboard | Giảm hiệu ứng thẻ nhấc lên; thống nhất nền, viền, cấp chữ và trạng thái tab. Tạo ưu tiên bằng độ tương phản của hành động. | Thứ tự hành động, khối đề thi, tab và danh sách. |
| Soạn bài | Làm rõ lựa chọn công cụ, trạng thái lưu và nút hành động bằng cùng bộ token. | Toolbar và các điều khiển riêng của chế độ soạn bài. |
| Sảnh vào lớp | Thống nhất nền preview, điều khiển thiết bị, trường link và trạng thái kết nối. | Vị trí camera preview, thông tin buổi học và nút vào lớp. |
| Studio | Giảm cảm giác từng công cụ là một thẻ trang trí; thống nhất chrome, màu chọn, đường phân cách, độ nổi panel. | Bảng, thanh công cụ, camera PIP, panel phủ và điều khiển buổi học. |
| Đề thi | Đồng bộ tiêu đề, trường nhập, bảng/danh sách, bộ lọc, nút và thông báo. | Các trang, biểu mẫu, phân quyền giáo viên/admin và cách điều hướng hiện tại. |
| Dialog/panel/tiện ích | Áp dụng cùng bộ màu, viền, kiểu nút, icon và phản hồi tương tác. | Điểm mở, vị trí, kích thước và thứ tự thao tác. |

## 6. Trạng thái và tương tác

Áp dụng nhất quán default, hover, focus, pressed, selected, disabled, loading, error và success tại các thành phần đang có trạng thái đó. Focus phải nhìn thấy được; không phân biệt trạng thái chỉ bằng màu. Không thêm bước hoặc đổi ý nghĩa một thao tác.

Giữ nội dung/trạng thái thật: danh sách rỗng, đang tải, mất kết nối, lỗi backend, từ chối quyền camera/mic, đang lưu/lưu lỗi, tên bài dài và dữ liệu nhiều dòng. Giao diện không được khiến dữ liệu mô phỏng hoặc trạng thái chưa xác minh trông như đã hoạt động thật.

Hover ưu tiên đổi nền, viền hoặc màu icon, không nhấc thẻ hay phóng to gây xao nhãng. Chuyển trạng thái ngắn và có phương án giảm chuyển động theo hệ thống. Giữ phím tắt, tooltip và hành vi bút viết hiện tại.

## 7. Thứ tự triển khai và vai trò của fk

1. **Chụp hiện trạng và `fk spec`:** ghi nhận màn hình thật và trích hệ thị giác đang có vào `DESIGN.md`. Phân biệt token đang dùng với preset chưa được nối vào app; ví dụ có preset dark nhưng `main.dart` hiện dùng light.
2. **`fk tokens` + `fk color`:** thống nhất vai trò màu trong `constants/theme.dart`, `theme/app_color_theme.dart` và `ThemeData`. Thay màu hardcode theo vai trò; không thay màu nét vẽ, PDF hoặc nội dung do giáo viên chọn. Đo contrast thay vì mặc định mọi cặp màu hiện tại đều đạt AA.
3. **`fk type` + `fk calm`:** đồng bộ chữ, icon, viền, bo góc, bóng và phản hồi hover. Không chạy lượt tối ưu spacing hoặc bố cục mới.
4. **Áp dụng theo đợt:** đăng nhập và dashboard → sảnh → studio/soạn bài → đề thi → các dialog/panel/tiện ích. So ảnh trước/sau ở cùng kích thước sau từng đợt.
5. **`fk check` + `fk finish`:** kiểm tra tương phản, trạng thái, độ ổn định bố cục và các luồng quan trọng. Ghi lại hệ đã chốt trong `DESIGN.md`.

Các reference phù hợp: `spec.md`, `tokens.md`, `color.md`, `type.md`, `calm.md`, `product.md`, `check.md`, `finish.md` trong `.agents/skills/fk/reference/`. Chỉ dùng phần phù hợp với phạm vi thay diện mạo; đề xuất thay đổi cấu trúc phải được loại khỏi lượt này.

## 8. Tiêu chí nghiệm thu

- Ảnh trước/sau có cùng vị trí khối, kích thước vùng làm việc và thứ tự điều khiển. Thay typography không gây thêm dòng, cắt nhãn hoặc tràn khung.
- Cùng vai trò dùng cùng kiểu thể hiện trên mọi màn hình. Văn bản thường đạt contrast tối thiểu 4.5:1; chữ lớn và thành phần phi văn bản thiết yếu đạt tối thiểu 3:1.
- Chế độ soạn bài và lớp trực tiếp tiếp tục có đúng bộ điều khiển của từng chế độ. Trạng thái selected, focus và lỗi dễ nhận ra khi dùng chuột, bàn phím hoặc bút.
- Đối chiếu ở 1366×768, 1440×900 và 1920×1080; kiểm tra thêm Windows scaling 125%. Đây là các mốc nghiệm thu đề xuất, không phải số liệu thiết bị đã được người dùng xác nhận.
- Kiểm tra chức năng sau khi triển khai bằng phân tích Dart và các test hiện có phù hợp: đăng nhập, dashboard, soạn bài, studio, sảnh và module đề thi. Kiểm tra thủ công bút viết và nội dung được chia sẻ để tránh ảnh hưởng luồng dạy thực tế.
- Bằng chứng sau triển khai: 163 test qua, Dart analysis sạch, web và Windows release build thành công; 24 scene đối chiếu hình học. Ảnh Flutter thật và log lưu tại `evidence/`. Kiểm tra bút/camera/Meet vật lý chưa thực hiện trong môi trường này, xem giới hạn tại `implementation.md`.

## 9. Bước xác nhận

Người dùng xác nhận hướng xanh dương–slate tiết chế, dùng nhận diện/font hiện có và phạm vi chỉ thay diện mạo trước khi triển khai. Không cần chọn lại bố cục A/B/C.
