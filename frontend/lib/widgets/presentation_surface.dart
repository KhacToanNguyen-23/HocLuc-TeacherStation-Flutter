import 'dart:async';
import 'package:flutter/material.dart';
import '../models/studio_state.dart';
import '../services/teacher_media_service.dart';

Rect cameraRect(Size size, StudioState studio) {
  final width = size.width * studio.pipWidthFraction;
  final height = width * 9 / 16;
  return Rect.fromLTWH(
    (size.width - width) * studio.pipPosition.dx.clamp(0, 1),
    (size.height - height) * studio.pipPosition.dy.clamp(0, 1),
    width,
    height,
  );
}

/// Control widgets are siblings of this boundary and cannot enter the output.
class PresentationSurface extends StatefulWidget {
  const PresentationSurface({
    super.key,
    required this.studio,
    required this.child,
    this.manageCamera = true,
  });
  final StudioState studio;
  final Widget child;
  final bool manageCamera;
  @override
  State<PresentationSurface> createState() => _PresentationSurfaceState();
}

class _PresentationSurfaceState extends State<PresentationSurface> {
  final _media = TeacherMediaService();
  bool? _lastCameraVisible;
  @override
  void initState() {
    super.initState();
    if (widget.manageCamera) {
      widget.studio.addListener(_syncCamera);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncCamera();
      });
    }
  }

  void _syncCamera() {
    final visible = widget.studio.showCameraPip;
    if (_lastCameraVisible == visible) return;
    _lastCameraVisible = visible;
    if (visible) {
      unawaited(_media.initMedia());
    } else {
      unawaited(_media.shutdown());
    }
  }

  @override
  void dispose() {
    if (widget.manageCamera) {
      widget.studio.removeListener(_syncCamera);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: ListenableBuilder(
      listenable: Listenable.merge([widget.studio, _media]),
      builder: (context, _) => LayoutBuilder(
        builder: (context, constraints) {
          final rect = cameraRect(constraints.biggest, widget.studio);
          return Stack(
            fit: StackFit.expand,
            children: [
              widget.child,
              if (widget.studio.showCameraPip)
                Positioned.fromRect(
                  rect: rect,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _media.buildCameraPreview(),
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}
