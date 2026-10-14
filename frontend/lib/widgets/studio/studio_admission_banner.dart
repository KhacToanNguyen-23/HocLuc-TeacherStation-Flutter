import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/meet_events.dart';
import '../../services/meet_automation_service.dart';
import 'google_meet_panel_dialog.dart';

/// The teacher approves on the board. Only a confirmed Meet result removes the
/// acted-on request; unknown identities and failures retain an in-app fallback.
class StudioAdmissionBanner extends StatelessWidget {
  const StudioAdmissionBanner({super.key, required this.meetService});
  final MeetAutomationService meetService;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: meetService,
    builder: (context, _) {
      if (meetService.pendingAdmitCount <= 0) return const SizedBox.shrink();
      return Positioned.fill(
        child: LayoutBuilder(
          builder: (context, box) => Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: math.min(430.0, math.max(0.0, box.maxWidth - 24)),
                child: Material(
                  elevation: 4,
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: math.min(
                        360.0,
                        math.max(0.0, box.maxHeight - 24),
                      ),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Yêu cầu vào lớp',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          for (final request in meetService.admissionRequests)
                            _requestTile(context, request),
                          if (meetService.unknownAdmissionCount > 0) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Có ${meetService.unknownAdmissionCount} yêu cầu chưa đọc được tên. Hãy kiểm tra trong Meet.',
                            ),
                            TextButton(
                              onPressed: () => GoogleMeetPanelDialog.show(
                                context,
                                meetService: meetService,
                              ),
                              child: const Text('Mở panel Meet'),
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
        ),
      );
    },
  );

  Widget _requestTile(BuildContext context, MeetAdmissionRequest request) {
    final busy = meetService.isAdmitting(request.id);
    final error = meetService.admissionError(request.id);
    return Padding(
      key: ValueKey('admission-${request.id}'),
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            request.name,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (request.detail.isNotEmpty)
            Text(request.detail, style: Theme.of(context).textTheme.bodySmall),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                error,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          if (busy)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Đang chờ Meet xác nhận…',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        final admitted = await meetService.admitRequest(
                          request.id,
                        );
                        if (context.mounted && admitted) {
                          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                            SnackBar(
                              content: Text(
                                'Meet đã xác nhận ${request.name} vào phòng.',
                              ),
                            ),
                          );
                        }
                      },
                child: Text(error == null ? 'Cho vào' : 'Kiểm tra lại'),
              ),
              TextButton(
                onPressed: busy
                    ? null
                    : () => GoogleMeetPanelDialog.show(
                        context,
                        meetService: meetService,
                      ),
                child: const Text('Mở Meet'),
              ),
              if (error != null)
                TextButton(
                  onPressed: busy
                      ? null
                      : () => meetService.dismissAdmissionNotice(request.id),
                  child: const Text('Đóng thông báo'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
