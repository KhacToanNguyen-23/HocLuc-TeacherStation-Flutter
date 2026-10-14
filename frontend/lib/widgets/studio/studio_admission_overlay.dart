import 'package:flutter/material.dart';

import '../../services/meet_automation_service.dart';
import 'studio_admission_banner.dart';

/// Teacher-only requests stay above each teaching view, outside video capture.
class StudioAdmissionOverlay extends StatelessWidget {
  const StudioAdmissionOverlay({
    super.key,
    required this.child,
    this.interactive = true,
    this.meetService,
  });
  final Widget child;
  final bool interactive;
  final MeetAutomationService? meetService;

  @override
  Widget build(BuildContext context) => !interactive
      ? child
      : Stack(
          fit: StackFit.expand,
          children: [
            child,
            StudioAdmissionBanner(
              meetService: meetService ?? MeetAutomationService(),
            ),
          ],
        );
}
