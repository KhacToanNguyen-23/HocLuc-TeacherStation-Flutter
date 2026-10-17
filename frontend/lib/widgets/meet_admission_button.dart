import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../services/meet_automation_service.dart';

/// Lets existing app toolbars open the shared admission box above routes.
class MeetAdmissionScope extends InheritedWidget {
  const MeetAdmissionScope({
    super.key,
    required this.service,
    required this.open,
    required this.isOpen,
    required this.revision,
    required super.child,
  });

  final MeetAutomationService service;
  final void Function(BuildContext anchor, {bool showMeet}) open;
  final bool isOpen;
  final int revision;

  static MeetAdmissionScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MeetAdmissionScope>();

  @override
  bool updateShouldNotify(MeetAdmissionScope oldWidget) =>
      service != oldWidget.service ||
      isOpen != oldWidget.isOpen ||
      revision != oldWidget.revision;
}

/// An ordinary toolbar button, visible whenever a Meet room is open.
class MeetAdmissionButton extends StatelessWidget {
  const MeetAdmissionButton({super.key, this.color});
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scope = MeetAdmissionScope.maybeOf(context);
    if (scope == null) return const SizedBox.shrink();
    final count = scope.service.pendingAdmitCount;
    if (scope.service.meetingUrl == null && count == 0) {
      return const SizedBox.shrink();
    }
    return Semantics(
      label: '$count yêu cầu vào lớp đang chờ',
      child: IconButton(
        key: const Key('meet-admission-menu'),
        tooltip: 'Yêu cầu vào lớp ($count)',
        onPressed: () => scope.open(context, showMeet: false),
        style: IconButton.styleFrom(
          minimumSize: const Size(44, 44),
          padding: EdgeInsets.zero,
          foregroundColor: color ?? AppColors.primary,
        ),
        icon: Badge(
          key: const Key('meet-admission-dot'),
          isLabelVisible: count > 0,
          backgroundColor: AppColors.error,
          child: const Icon(Icons.person_add_alt_1_rounded, size: 20),
        ),
      ),
    );
  }
}
