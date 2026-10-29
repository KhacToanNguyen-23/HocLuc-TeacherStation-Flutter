# Phase 4: Ghim Bảng Đen Canva, Đóng gói Marketplace & Kiểm thử Toàn diện

## Mục tiêu
Hoàn thiện cơ chế ghim ảnh/SVG sắc nét từ Excalidraw sang Bảng đen chính (`StudioBoard`), đóng gói plugin thành file `.hlep` chuẩn Marketplace, và chạy toàn bộ các cổng kiểm thử tự động (CI Gate).

## File tác động
- `plugins/math_studio/ui/export/board_export.js`
- Đóng gói: `plugins/math_studio.hlep`
- Cập nhật và kiểm thử CI:
  - `node scripts/package_plugin.mjs math_studio`
  - `node scripts/validate_plugins.mjs`
  - `flutter test test/architecture_test.dart`
  - `flutter analyze --no-fatal-infos`

## Các bước triển khai
1. **Cơ chế Ghim Bảng Đen**:
   - Khi ở Trang 1 (Đồ thị), Trang 2 (BBT) hoặc Trang 3 (Tích phân/Khối tròn xoay):
   - Bấm nút "📌 Ghim vào bảng" $\rightarrow$ Xuất ảnh sắc nét độ phân giải 2x (PNG Base64 hoặc vector SVG) từ Excalidraw / BBT Table.
   - Gửi tin nhắn qua SDK Bridge:
     ```javascript
     window.HocLuc.postMessage({
       action: 'board:insert_annotation',
       payload: {
         type: 'com.hocluc.plugin.math_studio',
         data: {
           title: currentTitle,
           rawText: currentFormula,
           imageBase64: dataUrl,
           svgContent: svgString,
           aspectRatio: isBBT ? 1.6 : 1.33
         }
       }
     });
     ```
2. **Khả năng tương tác Canva trên Bảng Đen**:
   - Thẻ đồ thị xuất hiện trên bảng đen với 8 điểm neo Canva (corner/edge resize) và cuống xoay $360^\circ$ (rotation handle).
3. **Đóng gói Plugin Marketplace**:
   - Chạy lệnh: `node scripts/package_plugin.mjs math_studio` để tạo file archive `.hlep` mới nhất.
4. **Kiểm thử tự động & Báo cáo kết quả**:
   - `node scripts/validate_plugins.mjs`: Xác thực 4/4 plugins hợp lệ.
   - `flutter test test/architecture_test.dart`: 12/12 invariants vượt qua (100%).
   - `flutter analyze --no-fatal-infos`: 0 errors, 0 warnings.

## Tiêu chí hoàn thành (Verification)
- Toàn bộ 4 lệnh kiểm tra trên đều chạy thành công 100%.
- Bấm ghim từ bất kỳ trang nào đều dán được thẻ sticker đẹp mắt lên bảng đen, co giãn và xoay góc mượt mà.

