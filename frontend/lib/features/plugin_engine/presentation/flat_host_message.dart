import 'dart:ui';

/// A plugin message paired with the host-owned identity and geometry of its view.
class FlatHostMessage {
  const FlatHostMessage({
    required this.data,
    required this.viewToken,
    required this.navigationGeneration,
    required this.webViewBounds,
    this.executeJs,
  });

  final dynamic data;
  final String viewToken;
  final int navigationGeneration;
  final Rect webViewBounds;
  final void Function(String js)? executeJs;
}
