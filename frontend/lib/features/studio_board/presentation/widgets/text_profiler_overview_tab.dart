import 'package:flutter/material.dart';
import '../../domain/models/text_profile_models.dart';
import 'text_profiler_tab_views.dart';

class TextProfilerOverviewTab extends StatelessWidget {
  final TextProfileResult profile;
  final String rawText;

  const TextProfilerOverviewTab({
    super.key,
    required this.profile,
    required this.rawText,
  });

  @override
  Widget build(BuildContext context) {
    final flesch = profile.readabilityMetrics.firstWhere(
      (m) => m.id == 'flesch_reading_ease',
      orElse: () => profile.readabilityMetrics.first,
    );

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextProfilerTabViews.buildMetricHighlightCard(
                  title: 'Phân loại Khung CEFR',
                  value: profile.dominantCefrLevel,
                  subtitle: 'Độ khó ngữ liệu trọng tâm',
                  color: const Color(0xfff59e0b),
                  icon: Icons.workspace_premium_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextProfilerTabViews.buildMetricHighlightCard(
                  title: 'Flesch Reading Ease',
                  value: '${flesch.score}',
                  subtitle: flesch.gradeLevelEquivalent,
                  color: const Color(0xff86efac),
                  icon: Icons.menu_book_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextProfilerTabViews.buildMetricHighlightCard(
                  title: 'Độ dài câu Trung bình',
                  value: '${profile.statistics.avgSentenceLength}',
                  subtitle:
                      '${profile.syntacticComplexity.longSentences} câu dài > 25 từ',
                  color: const Color(0xff89b4fa),
                  icon: Icons.format_align_left_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextProfilerTabViews.buildMetricHighlightCard(
                  title: 'Đa dạng Từ vựng (TTR)',
                  value: '${profile.lexicalDiversity.ttr}',
                  subtitle: 'MTLD: ${profile.lexicalDiversity.mtld}',
                  color: const Color(0xffcba6f7),
                  icon: Icons.psychology_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0x18ffffff),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x28ffffff)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Color(0xff89b4fa),
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Tóm tắt Đánh giá Ngữ liệu Sư phạm',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '• Văn bản gồm ${profile.statistics.totalWords} từ phân bố trên ${profile.statistics.totalSentences} câu. Dải từ vựng B2–C1 chiếm ${((profile.cefrPercentages['B2'] ?? 0) + (profile.cefrPercentages['C1'] ?? 0)).toStringAsFixed(1)}% nội dung.\n'
                  '• Đạt chuẩn tương đương ${flesch.interpretation}\n'
                  '• ${profile.recommendations.isNotEmpty ? profile.recommendations.first.description : "Văn bản đạt độ khó cân bằng cho đối tượng học sinh THPT / ĐGNL."}',
                  style: const TextStyle(
                    color: Color(0xffcdd6f4),
                    fontSize: 12.5,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Trích dẫn Đoạn văn:',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0x10ffffff),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0x18ffffff)),
            ),
            child: Text(
              rawText,
              style: const TextStyle(
                color: Color(0xffbac2de),
                fontSize: 12,
                height: 1.45,
                fontFamily: 'Literata',
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
