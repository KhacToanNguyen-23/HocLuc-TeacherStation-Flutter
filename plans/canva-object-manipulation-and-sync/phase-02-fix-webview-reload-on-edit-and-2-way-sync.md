# Phase 2: Fix WebView Reload on Edit & 2-Way Sync

## 1. Goal
Đảm bảo khi người dùng bấm `✏️ Sửa` trên bất kỳ đồ thị nào, WebView nổi của plugin Math Studio tự động reload và nạp chính xác $100\%$ các thông số (công thức, cận tích phân, điểm cực trị) của đồ thị đó.

## 2. Changes
- `frontend/lib/features/plugin_engine/presentation/flat_host_native.dart`:
  - Thêm `didUpdateWidget(oldWidget)`:
    ```dart
    @override
    void didUpdateWidget(covariant FlatHost oldWidget) {
      super.didUpdateWidget(oldWidget);
      if (oldWidget.url != widget.url && ready) {
        final targetUrl = _resolveUrl(widget.url);
        windows?.loadUrl(targetUrl);
        macos?.loadRequest(Uri.parse(targetUrl));
      }
    }
    ```
- `frontend/lib/features/plugin_engine/presentation/floating_plugin_window.dart`:
  - Gán `key: ValueKey('flat_host_${plugin.manifest.id}_${studio.editingSticker?.id ?? "default"}')` cho `FlatHost`.
  - Trong `onControllerReady`, gọi ngay `window.__hocluc_load_edit(editData)` để nạp trực tiếp nếu WebView đã khởi tạo xong.

