import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_windows/webview_windows.dart' as win;

/// Host-owned permission UI avoids browser popups inside the offscreen texture.
/// The root navigator also serves Meet overlays mounted above the Navigator.
class MeetPermissionPrompt {
  static final navigatorKey = GlobalKey<NavigatorState>();
  static final _queues = Expando<Future<void>>();

  static Future<win.WebviewPermissionDecision> request(
    String url,
    win.WebviewPermissionKind kind, {
    required bool Function() isActive,
    Future<void>? cancelled,
  }) {
    final uri = Uri.tryParse(url);
    final resource = switch (kind) {
      win.WebviewPermissionKind.camera => 'camera',
      win.WebviewPermissionKind.microphone => 'microphone',
      win.WebviewPermissionKind.clipboardRead => 'bộ nhớ tạm',
      _ => null,
    };
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'meet.google.com' ||
        uri.port != 443 ||
        resource == null) {
      return Future.value(win.WebviewPermissionDecision.deny);
    }
    final navigator = navigatorKey.currentState;
    if (navigator == null || !isActive()) {
      return Future.value(win.WebviewPermissionDecision.deny);
    }
    final result = Completer<win.WebviewPermissionDecision>();
    // Camera and microphone can be requested together. Ask one at a time.
    _queues[navigator] = (_queues[navigator] ?? Future<void>.value()).then((
      _,
    ) async {
      var decision = win.WebviewPermissionDecision.deny;
      try {
        final context = navigator.mounted ? navigator.overlay?.context : null;
        if (isActive() && context != null && context.mounted) {
          final answer = await _showPrompt(
            context,
            resource,
            navigator.overlay!,
            cancelled,
          );
          if (isActive()) {
            decision = answer;
          }
        }
      } catch (_) {
        // Always resolve WebView2's native deferral, even during navigation.
      }
      result.complete(decision);
    });
    return result.future;
  }

  static Future<win.WebviewPermissionDecision> _showPrompt(
    BuildContext context,
    String resource,
    OverlayState fallbackOverlay,
    Future<void>? cancelled,
  ) async {
    final answer = Completer<win.WebviewPermissionDecision>();
    void finish(win.WebviewPermissionDecision decision) {
      if (!answer.isCompleted) answer.complete(decision);
    }

    // MeetAdmissionShell is above the Navigator. Insert above its overlay too,
    // so the small panel cannot cover or intercept the consent buttons.
    final overlay =
        Overlay.maybeOf(context, rootOverlay: true) ?? fallbackOverlay;
    final entry = OverlayEntry(
      builder: (context) => Positioned.fill(
        child: Material(
          type: MaterialType.transparency,
          child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.escape): () =>
                  finish(win.WebviewPermissionDecision.deny),
            },
            child: FocusScope(
              autofocus: true,
              child: Stack(
                children: [
                  ModalBarrier(
                    key: const Key('meet-permission-dismiss'),
                    color: Colors.black54,
                    dismissible: true,
                    onDismiss: () => finish(win.WebviewPermissionDecision.deny),
                  ),
                  Center(
                    child: AlertDialog(
                      title: Text('Cho phép Google Meet truy cập $resource?'),
                      content: const Text(
                        'Trang yêu cầu: https://meet.google.com',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () =>
                              finish(win.WebviewPermissionDecision.deny),
                          child: const Text('Không cho phép'),
                        ),
                        FilledButton(
                          onPressed: () =>
                              finish(win.WebviewPermissionDecision.allow),
                          child: const Text('Cho phép'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    try {
      return await Future.any([
        answer.future,
        if (cancelled != null)
          cancelled.then((_) => win.WebviewPermissionDecision.deny),
      ]);
    } finally {
      if (overlay.mounted) entry.remove();
      entry.dispose();
    }
  }
}

/// Every Meet surface must install the handler when the Webview first mounts.
/// The plugin stores that handler on the controller, so its lifetime must span
/// all mounted views using that controller, including the cockpit and overlay.
class MeetPermissionSession {
  int _surfaces = 0;
  Completer<void> _closed = Completer<void>();

  void attach() {
    if (_surfaces == 0) _closed = Completer<void>();
    _surfaces++;
  }

  void detach() {
    assert(_surfaces > 0);
    _surfaces--;
    if (_surfaces == 0) _closed.complete();
  }

  Future<win.WebviewPermissionDecision> request(
    String url,
    win.WebviewPermissionKind kind,
    bool isUserInitiated,
  ) => MeetPermissionPrompt.request(
    url,
    kind,
    isActive: () => _surfaces > 0,
    cancelled: _closed.future,
  );
}

class MeetWebview extends StatefulWidget {
  const MeetWebview({super.key, required this.controller});
  final win.WebviewController controller;

  @override
  State<MeetWebview> createState() => _MeetWebviewState();
}

class _MeetWebviewState extends State<MeetWebview> {
  static final _sessions = Expando<MeetPermissionSession>();
  late MeetPermissionSession _session;

  void _attach() {
    _session = _sessions[widget.controller] ??= MeetPermissionSession();
    _session.attach();
  }

  @override
  void initState() {
    super.initState();
    _attach();
  }

  @override
  void didUpdateWidget(MeetWebview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _session.detach();
      _attach();
    }
  }

  @override
  void dispose() {
    _session.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => KeyedSubtree(
    key: ObjectKey(widget.controller),
    child: win.Webview(
      widget.controller,
      permissionRequested: _session.request,
    ),
  );
}
