# Phase 05: Flutter Host Pixel-Snapping, Caching, 3-Button Sticker Bar & CI Verification

## Objective
Fix WebView2 sub-pixel texture blurring and cold-start overhead in the Flutter Host, streamline `BoardStickerFloatingBar` to the 3 essential working actions (`✎ Sửa`, `⧉ Nhân bản`, `🗑 Xóa`), remove the hardcoded `'math'` plugin ID check in `interactive_chalkboard.dart`, repackage `math_studio.hlep`, and pass all CI verification gates.

## Files to Modify
1. `frontend/lib/features/plugin_engine/presentation/floating_plugin_window.dart`
   - Round `dialogW`, `dialogH`, `centerLeft`, and `centerTop` using `.roundToDouble()` so the WebView2 Direct3D texture always aligns to exact integer logical pixels (eliminating `.5px` bilinear font blurring).
   - Keep `FlatHost` key stable per plugin (`ValueKey('flat_host_${plugin.manifest.id}')`) so editing different stickers reuses the warm WebView controller via `window.__hocluc_load_edit` instead of disposing and cold-starting WebView2.
   - Pass full sticker metadata (`formula`, `a`, `b`, `view`, `preset`, `problem`, `color`) in both URL query params and `window.__hocluc_load_edit`.
2. `frontend/lib/features/plugin_engine/services/plugin_web_server.dart` & `frontend/assets/scripts/hocluc-plugin-sdk.js`
   - In `PluginWebServer._servePluginFile`, set `Cache-Control: public, max-age=86400` for immutable `/vendor/` assets (`jsxgraphcore.js`, `jsxgraph.css`) while keeping `no-cache` for plugin application files.
   - In `assets/scripts/hocluc-plugin-sdk.js`, ensure `window.HocLuc.close()` (alias for `window.HocLuc.window.close()`) and `window.HocLuc.onMessage(callback)` are defined so plugins can close modals and receive edit payloads cleanly.
3. `frontend/lib/features/studio_board/presentation/board_sticker_floating_bar.dart`
   - Remove the 8 fake/duplicate buttons (`Phát quay`, `Góc nhìn: Sách GK | Trước | Trên | Bên | Xoay 3D`, `Sao chép`, `Cắt`).
   - Render a sleek, compact Pill Action Bar (`height: 36`, `borderRadius: 999`) containing only the **3 essential, working buttons**:
     1. **`✎ Sửa`** (`onEdit`)
     2. **`⧉ Nhân bản`** (`onDuplicate`)
     3. **`🗑 Xóa`** (`onDelete`)
4. `frontend/lib/features/studio_board/presentation/interactive_chalkboard.dart` & `board_sticker_card.dart`
   - Update floating bar width from `540.0` to `220.0` in `interactive_chalkboard.dart` (`_calculateBarLeft`) and `board_sticker_card.dart`.
   - Remove `(s.svgContent != null && p.manifest.id.contains('math'))` at line 271 of `interactive_chalkboard.dart` (strictly adhering to `AGENTS.md` Invariant #1: Zero Hardcoded Names in `frontend/lib/`) and remove unused `_handleRevolveOrEdit`.

## Packaging & CI Verification Gates
1. Run `node scripts/package_plugin.mjs math_studio` to rebuild `plugins/math_studio.hlep` and sync local cache if present.
2. Run `node scripts/validate_plugins.mjs` (0 errors).
3. Run `flutter test test/architecture_test.dart` (12/12 invariants passing).
4. Run `flutter analyze --no-fatal-infos` (0 errors, 0 warnings).

