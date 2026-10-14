import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/studio_state.dart';
import '../floating_pip.dart';

/// Reuses the shared controls so additions to camera routing stay visible here.
class MediaBroadcastControlsButton extends StatelessWidget {
  const MediaBroadcastControlsButton({super.key, required this.studio});
  final StudioState studio;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    icon: const Icon(Icons.videocam_outlined),
    label: const Text('Camera, micro & phát hình'),
    onPressed: () => showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: SizedBox(
          width: 480,
          height: math.min(360, MediaQuery.sizeOf(context).height - 64),
          child: FloatingPip(studio: studio, controlsOnly: true),
        ),
      ),
    ),
  );
}
