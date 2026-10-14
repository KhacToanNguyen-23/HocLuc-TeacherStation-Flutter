import 'package:flutter/widgets.dart';
import '../services/camera_broadcast_service.dart';

/// Wraps the app Navigator so menus, drawers, and dialogs are captured too.
class AppCaptureSurface extends StatefulWidget {
  const AppCaptureSurface({super.key, required this.child});
  final Widget child;
  @override
  State<AppCaptureSurface> createState() => _AppCaptureSurfaceState();
}

class _AppCaptureSurfaceState extends State<AppCaptureSurface> {
  final _key = GlobalKey();
  @override
  void initState() {
    super.initState();
    CameraBroadcastService().attachApp(_key);
  }

  @override
  void dispose() {
    CameraBroadcastService().detachApp(_key);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      RepaintBoundary(key: _key, child: widget.child);
}
