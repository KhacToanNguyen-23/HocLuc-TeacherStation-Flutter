# Phase 1: Thanh lọc mã nguồn Flutter Host (Purge Host Bleed & Restore Clean Microkernel)

## Mục tiêu
Loại bỏ 100% mã toán học, các widget tự vẽ và runtime QuickJS khỏi `frontend/lib/`, trả lại Flutter Host về vai trò Microkernel trung lập và sạch sẽ.

## File tác động
- Xóa: `frontend/lib/features/plugin_engine/presentation/native_plugin_host.dart`
- Xóa: `frontend/lib/features/plugin_engine/presentation/native_scene_canvas.dart`
- Xóa: `frontend/lib/features/plugin_engine/services/native_plugin_runtime.dart`
- Xóa: `frontend/test/features/plugin_engine/native_plugin_runtime_test.dart`
- Xóa: `scripts/bundle_plugin_logic.mjs`
- Sửa: `frontend/lib/features/plugin_engine/presentation/floating_plugin_window.dart` (loại bỏ nhánh `if (plugin.manifest.isNativeRuntime)`)
- Sửa: `frontend/lib/features/plugin_engine/domain/models/plugin_manifest.dart` (loại bỏ `isNativeRuntime`, `logicEntry`)
- Sửa: `frontend/pubspec.yaml` (gỡ bỏ dependency `flutter_js: ^0.8.7`)

## Các bước triển khai
1. Trong `floating_plugin_window.dart`:
   - Gỡ bỏ import `native_plugin_host.dart`.
   - Xóa bỏ khối điều kiện:
     ```dart
     if (plugin.manifest.isNativeRuntime) {
       return NativePluginHost(...);
     }
     ```
   - Đảm bảo toàn bộ luồng hiển thị plugin đi thẳng vào `FlatHost(...)`.
2. Trong `plugin_manifest.dart`:
   - Xóa các getter/property liên quan đến `native` runtime và `logic_entry`.
3. Xóa các file mã nguồn:
   - `frontend/lib/features/plugin_engine/presentation/native_plugin_host.dart`
   - `frontend/lib/features/plugin_engine/presentation/native_scene_canvas.dart`
   - `frontend/lib/features/plugin_engine/services/native_plugin_runtime.dart`
   - `frontend/test/features/plugin_engine/native_plugin_runtime_test.dart`
   - `scripts/bundle_plugin_logic.mjs`
4. Trong `frontend/pubspec.yaml`:
   - Xóa dòng `flutter_js: ^0.8.7`.
   - Chạy `flutter pub get`.

## Tiêu chí hoàn thành (Verification)
- Chạy `flutter test test/architecture_test.dart` vượt qua 12/12 invariants (100%).
- `frontend/lib/` không còn bất kỳ file nào có tiền tố `native_plugin_*`.

