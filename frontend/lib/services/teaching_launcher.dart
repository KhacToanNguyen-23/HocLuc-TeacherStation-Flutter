import 'package:flutter/material.dart';
import '../models/teaching_target.dart';
import '../screens/studio_screen.dart';
import 'local_service.dart';
import 'meet_automation_service.dart';
import 'teacher_media_service.dart';

/// Single navigation owner: preparation is inside Studio, never another lobby.
class TeachingLauncher {
  static Route<void>? _studioRoute;
  static NavigatorState? _navigator;
  static bool _opening = false;

  static bool get hasStudio => _studioRoute?.isActive == true;
  static void returnToStudio() {
    final route = _studioRoute;
    if (route != null && route.isActive) {
      _navigator?.popUntil((r) => identical(r, route));
    }
  }

  static Future<void> open(
    BuildContext context,
    TeachingTarget target, {
    LocalService? localService,
    Widget Function(TeachingTarget, String?)? studioBuilder,
    Future<void> Function()? leaveMeeting,
  }) async {
    if (_opening) return;
    _opening = true;
    bool holdingLaunch = true;
    final local = localService ?? LocalService();
    try {
      if (target.isLinked && target.meetingUrl == null) {
        throw StateError(
          'Lớp chưa có phòng Meet liên kết. Đồng bộ lớp trước khi bắt đầu.',
        );
      }
      await MeetAutomationService().pendingSessionRegistration;
      final active = await local.getActiveClassroom(strict: true);
      final activeUrl = active['meetingUrl'] as String?;
      final meet = MeetAutomationService();
      final sameRoom =
          target.meetingUrl != null &&
          (active['status'] == 'ONGOING'
              ? target.meetingUrl == activeUrl
              : target.meetingUrl == meet.meetingUrl);
      if (sameRoom && hasStudio) {
        returnToStudio();
        return;
      }
      final occupied =
          active['status'] == 'ONGOING' || hasStudio || meet.hasRoom;
      if (occupied && !sameRoom) {
        if (!context.mounted) return;
        final replace = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Chuyển sang lớp khác?'),
            content: Text(
              'Kết thúc buổi đang mở và chuyển sang “${target.title}”? Phòng Meet của từng lớp vẫn được giữ nguyên.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Ở lại'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Kết thúc và chuyển lớp'),
              ),
            ],
          ),
        );
        if (replace != true) return;
        if (active['status'] == 'ONGOING' &&
            !await local.endClassroom(classroomId: active['id'] as String?)) {
          throw StateError(
            'Chưa kết thúc được buổi hiện tại. Chưa chuyển lớp.',
          );
        }
        await (leaveMeeting ?? meet.leaveClassroom)();
        if (leaveMeeting == null) await TeacherMediaService().shutdown();
        final previous = _studioRoute;
        _studioRoute = null;
        if (previous?.isActive == true) _navigator?.removeRoute(previous!);
      }
      if (!context.mounted) return;
      if (target.planningId != null) {
        final cloned = await local.clonePlanningToClassroom(target.planningId!);
        if (!cloned) {
          throw StateError('Chưa chuẩn bị được bài giảng. Vui lòng thử lại.');
        }
      }
      if (!context.mounted) return;
      final sessionId = sameRoom ? active['id'] as String? : null;
      final route = MaterialPageRoute<void>(
        settings: RouteSettings(
          name:
              '/teaching/${target.courseId ?? target.meetingUrl ?? 'one-off'}',
        ),
        builder: (_) =>
            studioBuilder?.call(target, sessionId) ??
            StudioScreen(
              lessonTitle: target.title,
              meetingUrl: target.meetingUrl,
              teachingTarget: target,
              initialSessionId: sessionId,
            ),
      );
      _studioRoute = route;
      _navigator = Navigator.of(context);
      final closed = _navigator!.pushAndRemoveUntil<void>(
        route,
        (r) => r.isFirst,
      );
      _opening = false;
      holdingLaunch = false;
      await closed;
      if (identical(_studioRoute, route)) {
        _studioRoute = null;
        _navigator = null;
      }
    } finally {
      if (holdingLaunch) _opening = false;
      if (localService == null) local.dispose();
    }
  }
}
