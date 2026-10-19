import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'meet_webview.dart';
import '../constants/theme.dart';
import '../services/meet_automation_service.dart';
import 'meet_admission_button.dart';

/// Lives above the Navigator, so requests survive routes, drawers and dialogs.
class MeetAdmissionShell extends StatefulWidget {
  const MeetAdmissionShell({
    super.key,
    required this.service,
    required this.child,
  });

  final MeetAutomationService service;
  final Widget child;

  @override
  State<MeetAdmissionShell> createState() => _MeetAdmissionShellState();
}

class _MeetAdmissionShellState extends State<MeetAdmissionShell> {
  final _surfaceKey = GlobalKey();
  FocusNode? _returnFocus;
  Rect _anchor = const Rect.fromLTWH(8, 60, 44, 44);
  final _popupFocus = FocusScopeNode();
  bool _open = false;
  bool _showMeet = false;
  String? _room;
  bool _refreshScheduled = false;
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    _room = widget.service.meetingUrl;
    widget.service.addListener(_changed);
  }

  @override
  void didUpdateWidget(MeetAdmissionShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service) {
      oldWidget.service.removeListener(_changed);
      widget.service.addListener(_changed);
      _room = widget.service.meetingUrl;
      _open = _showMeet = false;
    }
  }

  void _changed() {
    // A route may connect its room in initState while the Navigator builds.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      if (!_refreshScheduled) {
        _refreshScheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _refreshScheduled = false;
          if (mounted) _changed();
        });
      }
      return;
    }
    setState(() {
      _revision++;
      if (_room != widget.service.meetingUrl) {
        _open = _showMeet = false;
        _room = widget.service.meetingUrl;
      }
    });
  }

  void _show({bool meet = false, BuildContext? anchor}) {
    if (anchor != null) {
      final button = anchor.findRenderObject();
      final surface = _surfaceKey.currentContext?.findRenderObject();
      if (button is RenderBox && surface is RenderBox && button.hasSize) {
        _anchor =
            surface.globalToLocal(button.localToGlobal(Offset.zero)) &
            button.size;
      }
    }
    if (!_open) _returnFocus = FocusManager.instance.primaryFocus;
    setState(() {
      _open = true;
      _showMeet = meet;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _open) _popupFocus.requestFocus();
    });
  }

  void _close() {
    setState(() => _open = _showMeet = false);
    if (_returnFocus?.context != null) _returnFocus!.requestFocus();
  }

  @override
  void dispose() {
    widget.service.removeListener(_changed);
    _popupFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    final pending = service.pendingAdmitCount;
    return MeetAdmissionScope(
      service: service,
      isOpen: _open,
      revision: _revision,
      open: (anchor, {showMeet = false}) =>
          _show(meet: showMeet, anchor: anchor),
      child: Overlay.wrap(
        child: LayoutBuilder(
          builder: (context, box) {
            final width = math.min(
              _showMeet ? 960.0 : 384.0,
              box.maxWidth - 16,
            );
            final inset = MediaQuery.viewInsetsOf(context).bottom;
            final safeTop = MediaQuery.paddingOf(context).top + 8;
            final panelHeight = math.min(
              _showMeet ? box.maxHeight : 560.0,
              math.max(0.0, box.maxHeight - inset - safeTop - 8),
            );
            var left = _anchor.right + 8;
            if (left + width > box.maxWidth - 8) {
              left = _anchor.left - width - 8;
            }
            left = left
                .clamp(8.0, math.max(8.0, box.maxWidth - width - 8))
                .toDouble();
            final top = _anchor.top
                .clamp(
                  safeTop,
                  math.max(safeTop, box.maxHeight - inset - panelHeight - 8),
                )
                .toDouble();
            return Stack(
              key: _surfaceKey,
              children: [
                widget.child,
                if (_open) ...[
                  Positioned.fill(
                    child: GestureDetector(
                      key: const Key('meet-admission-dismiss'),
                      behavior: HitTestBehavior.opaque,
                      onTap: _close,
                      child: const ColoredBox(color: Colors.transparent),
                    ),
                  ),
                  Positioned(
                    left: left,
                    top: top,
                    width: width,
                    bottom: math.max(
                      12,
                      MediaQuery.viewInsetsOf(context).bottom,
                    ),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: CallbackShortcuts(
                        bindings: {
                          const SingleActivator(LogicalKeyboardKey.escape):
                              _close,
                        },
                        child: FocusScope(
                          node: _popupFocus,
                          autofocus: true,
                          child: Material(
                            key: const Key('meet-admission-popup'),
                            color: AppColors.surface,
                            elevation: 4,
                            shadowColor: AppColors.textPrimary.withValues(
                              alpha: .12,
                            ),
                            borderRadius: BorderRadius.circular(AppRadii.panel),
                            clipBehavior: Clip.antiAlias,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: _showMeet ? box.maxHeight : 560,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      8,
                                      4,
                                      8,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _showMeet
                                                ? 'Google Meet trong app'
                                                : 'Yêu cầu vào lớp ($pending)',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Đóng',
                                          onPressed: _close,
                                          icon: const Icon(Icons.close_rounded),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Divider(height: 1),
                                  if (_showMeet)
                                    Flexible(
                                      child: _MeetSessionPanel(
                                        service: service,
                                      ),
                                    )
                                  else ...[
                                    Flexible(
                                      child: SingleChildScrollView(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            if (pending == 0)
                                              const Padding(
                                                padding: EdgeInsets.symmetric(
                                                  vertical: 24,
                                                ),
                                                child: Text(
                                                  'Không còn yêu cầu chờ duyệt.',
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                            for (final request
                                                in service.admissionRequests)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 16,
                                                ),
                                                child: Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    const CircleAvatar(
                                                      backgroundColor:
                                                          AppColors.selected,
                                                      foregroundColor:
                                                          AppColors.primary,
                                                      child: Icon(
                                                        Icons
                                                            .person_outline_rounded,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            request.name,
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 14,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                ),
                                                          ),
                                                          if (request
                                                              .detail
                                                              .isNotEmpty)
                                                            Text(
                                                              request.detail,
                                                              style: const TextStyle(
                                                                fontSize: 12,
                                                                color: AppColors
                                                                    .textSecondary,
                                                              ),
                                                            ),
                                                          const SizedBox(
                                                            height: 4,
                                                          ),
                                                          Text(
                                                            service.isAdmitting(
                                                                  request.id,
                                                                )
                                                                ? 'Đang chờ Meet xác nhận…'
                                                                : service.admissionError(
                                                                        request
                                                                            .id,
                                                                      ) ??
                                                                      'Đang chờ bạn cho phép vào lớp',
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              color:
                                                                  service.admissionError(
                                                                        request
                                                                            .id,
                                                                      ) ==
                                                                      null
                                                                  ? AppColors
                                                                        .textSecondary
                                                                  : AppColors
                                                                        .error,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            if (service.unknownAdmissionCount >
                                                0)
                                              Text(
                                                '${service.unknownAdmissionCount} yêu cầu chưa đọc được tên tài khoản. Kiểm tra Meet trong app để duyệt.',
                                                style: const TextStyle(
                                                  color:
                                                      AppColors.textSecondary,
                                                  fontSize: 13,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const Divider(height: 1),
                                    Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          FilledButton.icon(
                                            key: const Key(
                                              'meet-admission-approve-all',
                                            ),
                                            style: FilledButton.styleFrom(
                                              minimumSize: const Size(44, 48),
                                            ),
                                            onPressed:
                                                service
                                                        .admissionRequests
                                                        .isEmpty ||
                                                    service.isAdmittingAll
                                                ? null
                                                : service.admitAllPending,
                                            icon: Icon(
                                              service.isAdmittingAll
                                                  ? Icons.hourglass_top_rounded
                                                  : Icons.done_all_rounded,
                                            ),
                                            label: Text(
                                              service.isAdmittingAll
                                                  ? 'Đang xác nhận…'
                                                  : 'Xác nhận tất cả',
                                            ),
                                          ),
                                          if (service.unknownAdmissionCount >
                                                  0 ||
                                              service.admissionRequests.any(
                                                (r) =>
                                                    service.admissionError(
                                                      r.id,
                                                    ) !=
                                                    null,
                                              ))
                                            TextButton(
                                              onPressed: () =>
                                                  _show(meet: true),
                                              child: const Text(
                                                'Kiểm tra Meet trong app',
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Reuses the teacher's existing cookie session, never an external browser.
class _MeetSessionPanel extends StatelessWidget {
  const _MeetSessionPanel({required this.service});
  final MeetAutomationService service;

  @override
  Widget build(BuildContext context) {
    final controller = service.webviewController;
    if (controller != null && controller.value.isInitialized) {
      return SizedBox(height: 640, child: MeetWebview(controller: controller));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            service.errorMessage ??
                'Kết nối phòng Meet trong app bằng tài khoản chủ phòng để nhận yêu cầu.',
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: service.status == MeetStatus.creating
                ? null
                : service.ensureHostJoined,
            child: Text(
              service.status == MeetStatus.creating
                  ? 'Đang kết nối…'
                  : 'Kết nối Meet trong app',
            ),
          ),
        ],
      ),
    );
  }
}
