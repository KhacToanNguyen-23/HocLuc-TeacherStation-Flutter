import 'package:flutter/material.dart';
import 'package:teaching_companion/constants/theme.dart';
import 'package:teaching_companion/core/platform/url_opener.dart';

class WorkspaceEventsCard extends StatelessWidget {
  const WorkspaceEventsCard({super.key, required this.events});

  final List<Map<String, dynamic>> events;

  static String _date(String iso) {
    final date = DateTime.tryParse(iso)?.toLocal();
    if (date == null) return iso;
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} · ${two(date.hour)}:${two(date.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Các buổi Calendar',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          for (final event in events.reversed)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.event_available_outlined,
                color: AppColors.primary,
              ),
              title: Text(_date(event['start'] as String)),
              subtitle: Text(
                'Đã yêu cầu Google gửi lịch cho ${event['inviteeCount']} học sinh',
              ),
              trailing: event['url'] == null || event['url'] == ''
                  ? null
                  : IconButton(
                      tooltip: 'Mở lịch Google',
                      onPressed: () => openExternalUrl(event['url'] as String),
                      icon: const Icon(Icons.open_in_new),
                    ),
            ),
        ],
      ),
    );
  }
}


