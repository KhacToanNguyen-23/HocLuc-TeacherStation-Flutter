import 'package:flutter/material.dart';

import '../../domain/models/dgnl_highlight_palette.dart';
import '../../domain/models/text_profile_models.dart';

class TextProfilerDialogHeader extends StatelessWidget {
  final TextProfileResult profile;
  final VoidCallback onClose;

  const TextProfilerDialogHeader({
    super.key,
    required this.profile,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final levelColor = DgnlHighlightPalette.tokenForLevel(
      profile.dominantCefrLevel,
    ).badgeDark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0x18ffffff),
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0x2889b4fa),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.analytics_outlined,
              color: Color(0xff89b4fa),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Flexible(
                      child: Text(
                        'Hồ sơ Độ khó Ngữ liệu Tiếng Anh',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: levelColor.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: levelColor, width: 1.2),
                      ),
                      child: Text(
                        'CEFR ${profile.dominantCefrLevel}',
                        style: TextStyle(
                          color: levelColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${profile.statistics.totalWords} từ • ${profile.statistics.totalSentences} câu • Độ dài câu TB ${profile.statistics.avgSentenceLength} từ • Offline profiler · background dictionary lookup',
                  style: const TextStyle(
                    color: Color(0xffa6adc8),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close, color: Colors.white70, size: 20),
            tooltip: 'Đóng (Esc)',
          ),
        ],
      ),
    );
  }
}
