import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:webview_windows/webview_windows.dart' as win;
import '../constants/theme.dart';
import '../services/meet_automation_service.dart';

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
  final _menuFocus = FocusNode();
  final _popupFocus = FocusScopeNode();
  bool _open = false;
  bool _showMeet = false;
  String? _room;
  bool _refreshScheduled = false;

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
      if (_room != widget.service.meetingUrl) {
        _open = _showMeet = false;
        _room = widget.service.meetingUrl;
      }
    });
  }

  void _show({bool meet = false}) {
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
    _menuFocus.requestFocus();
  }

  @override
  void dispose() {
    widget.service.removeListener(_changed);
    _menuFocus.dispose();
    _popupFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    final pending = service.pendingAdmitCount;
    final railVisible = service.meetingUrl != null || pending > 0;
    return Overlay.wrap(
      child: LayoutBuilder(
        builder: (context, box) {
          final compact = box.maxWidth < 600;
          final left = compact ? 8.0 : 64.0;
          final width = math.min(
            _showMeet ? 960.0 : 384.0,
            box.maxWidth - left - 8,
          );
          return Stack(
            children: [
              Row(
                children: [
                  if (railVisible)
                    Material(
                      color: Colors.white,
                      child: Container(
                        width: 56,
                        decoration: const BoxDecoration(
                          border: Border(
                            right: BorderSide(color: AppColors.slate200),
                          ),
                        ),
                        child: SafeArea(
                          child: Column(
                            children: [
                              const SizedBox(height: 12),
                              if (pending > 0 || _open)
                                Semantics(
                                  label: '$pending yêu cầu vào lớp đang chờ',
                                  child: IconButton(
                                    key: const Key('meet-admission-menu'),
                                    focusNode: _menuFocus,
                                    tooltip: 'Yêu cầu vào lớp ($pending)',
                                    isSelected: _open,
                                    color: AppColors.sky700,
                                    onPressed: () => _open ? _close() : _show(),
                                    icon: Badge(
                                      key: const Key('meet-admission-dot'),
                                      isLabelVisible: pending > 0,
                                      backgroundColor: AppColors.rose600,
                                      child: const Icon(
                                        Icons.person_add_alt_1_rounded,
                                      ),
                                    ),
                                  ),
                                ),
                              const Spacer(),
                              IconButton(
                                tooltip: 'Google Meet trong app',
                                onPressed: () => _show(meet: true),
                                icon: const Icon(Icons.video_call_outlined),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Expanded(child: widget.child),
                ],
              ),
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
                  top: MediaQuery.paddingOf(context).top + 12,
                  width: width,
                  bottom: math.max(12, MediaQuery.viewInsetsOf(context).bottom),
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
                          color: Colors.white,
                          elevation: 12,
                          shadowColor: Colors.black26,
                          borderRadius: BorderRadius.circular(16),
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
                                            fontWeight: FontWeight.w800,
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
                                    child: _MeetSessionPanel(service: service),
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
                                                        AppColors.sky50,
                                                    foregroundColor:
                                                        AppColors.sky700,
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
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 12,
                                                                  color: AppColors
                                                                      .slate600,
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
                                                                      .slate600
                                                                : AppColors
                                                                      .rose600,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          if (service.unknownAdmissionCount > 0)
                                            Text(
                                              '${service.unknownAdmissionCount} yêu cầu chưa đọc được tên tài khoản. Kiểm tra Meet trong app để duyệt.',
                                              style: const TextStyle(
                                                color: AppColors.slate600,
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
                                            backgroundColor: AppColors.sky700,
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
                                        if (service.unknownAdmissionCount > 0 ||
                                            service.admissionRequests.any(
                                              (r) =>
                                                  service.admissionError(
                                                    r.id,
                                                  ) !=
                                                  null,
                                            ))
                                          TextButton(
                                            onPressed: () => _show(meet: true),
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
      return SizedBox(height: 640, child: win.Webview(controller));
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
