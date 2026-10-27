import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Temporarily pans a surface without changing its selected drawing tool.
class MiddleMousePan extends StatefulWidget {
  const MiddleMousePan({
    super.key,
    required this.onPan,
    required this.child,
    this.enabled = true,
  });

  final ValueChanged<Offset> onPan;
  final Widget child;
  final bool enabled;

  @override
  State<MiddleMousePan> createState() => _MiddleMousePanState();
}

class _MiddleMousePanState extends State<MiddleMousePan> {
  int? _pointer;

  void _stop(int pointer) {
    if (_pointer == pointer) setState(() => _pointer = null);
  }

  @override
  void didUpdateWidget(covariant MiddleMousePan oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) _pointer = null;
  }

  @override
  Widget build(BuildContext context) {
    final panning = _pointer != null;
    return MouseRegion(
      cursor: panning ? SystemMouseCursors.grabbing : MouseCursor.defer,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) {
          if (widget.enabled &&
              _pointer == null &&
              event.kind == PointerDeviceKind.mouse &&
              event.buttons == kMiddleMouseButton) {
            setState(() => _pointer = event.pointer);
          }
        },
        onPointerMove: (event) {
          if (event.pointer != _pointer) return;
          if (!widget.enabled || event.buttons & kMiddleMouseButton == 0) {
            _stop(event.pointer);
            return;
          }
          widget.onPan(event.localDelta);
        },
        onPointerUp: (event) => _stop(event.pointer),
        onPointerCancel: (event) => _stop(event.pointer),
        child: IgnorePointer(ignoring: panning, child: widget.child),
      ),
    );
  }
}
