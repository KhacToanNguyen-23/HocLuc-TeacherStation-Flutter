# Phase 4: Dọn tàn dư, NOTICE, đóng gói, báo kích thước

## Mục tiêu
Plugin chỉ chứa code đang dùng; giấy phép rõ ràng; `.hlep` đồng bộ; số đo kích thước thật.

## File xoá (sau khi Phase 3 chạy ổn)
- `ui/board/graph_board.js`
- `ui/core/{math_cas,store,geometry_parser,integral_solver,rational,math_engine}.js`
- `ui/export/board_exporter.js`
- `ui/render/{bbt_generator,bbt_table,excalidraw_stage,math_keyboard}.js`
- `ui/vendor/jsxgraph/`, `ui/vendor/rough.js`, `ui/app.js` (bản cũ)
- Thư mục rỗng sau khi xoá.

## File tạo / sửa
- `NOTICE.txt`: liệt kê Excalidraw (MIT), React/ReactDOM (MIT), mathjs (Apache-2.0), nerdamer (Apache-2.0), roughjs (MIT, nằm trong Excalidraw) kèm nội dung giấy phép bắt buộc.
- `manifest.json`: giữ `inject_sdk:true`, quyền `board:insert_annotation`; kiểm `default_width/height`, `resizable`.
- Quyết định xử lý kích thước (reviewer phải xác nhận): (i) chỉ giảm bundle (tree-shake mathjs, tách phần không dùng), hoặc (ii) thêm deflate vào `package_plugin.mjs` (sửa cả `validate_plugins.mjs` nếu đụng quy tắc hash) — chọn (i) trước; chỉ làm (ii) nếu vẫn vượt ngưỡng đã chốt.

## Bước
1. Xoá file; chạy lại build + test Phase 1–3 (phải còn xanh).
2. `node scripts/package_plugin.mjs math_studio`.
3. `node scripts/validate_plugins.mjs` → phải 0 lỗi.
4. Đo và ghi: kích thước `ui/dist/app.js`, `.hlep`, số file.
5. Quét `frontend/lib/`: không có chuỗi tên plugin/môn toán mới; `flutter test test/architecture_test.dart` 12/12; `dart analyze` 0 issue. (Chỉ là bằng chứng kiến trúc, không phải bằng chứng chức năng.)

## Tiêu chí hoàn thành
Không còn file trong danh sách xoá; `.hlep` đồng bộ; số đo kích thước ghi vào Session Notes; NOTICE có đủ giấy phép.

