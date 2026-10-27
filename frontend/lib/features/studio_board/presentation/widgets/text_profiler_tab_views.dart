import 'package:flutter/material.dart';
import '../../domain/models/dgnl_highlight_palette.dart';
import '../../domain/models/text_profile_models.dart';

class TextProfilerTabViews {
  static Widget buildMetricHighlightCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x18ffffff),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xffa6adc8),
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Icon(icon, size: 14, color: color),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white70, fontSize: 10.5),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // --- TAB 3: ĐỘ KHÓ ĐỌC HIỂU (6 READABILITY METRICS) ---
  static Widget buildReadabilityTab(
    TextProfileResult profile,
    Set<String> expandedMetricIds,
    void Function(String id) onToggleExpand,
  ) {
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      itemCount: profile.readabilityMetrics.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (ctx, idx) {
        final metric = profile.readabilityMetrics[idx];
        final isExpanded = expandedMetricIds.contains(metric.id);

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0x18ffffff),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x28ffffff)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              metric.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (!metric.isReliable)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0x33f59e0b),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Cảnh báo mẫu ngắn',
                                  style: TextStyle(
                                    color: Color(0xfff59e0b),
                                    fontSize: 9.5,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          metric.interpretation,
                          style: const TextStyle(
                            color: Color(0xffcdd6f4),
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${metric.score}',
                        style: const TextStyle(
                          color: Color(0xff86efac),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        metric.gradeLevelEquivalent,
                        style: const TextStyle(
                          color: Color(0xff89b4fa),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: Colors.white70,
                      size: 18,
                    ),
                    onPressed: () => onToggleExpand(metric.id),
                  ),
                ],
              ),
              if (isExpanded) ...[
                const SizedBox(height: 10),
                const Divider(color: Color(0x20ffffff), height: 1),
                const SizedBox(height: 10),
                Text(
                  '• Phương pháp / Công thức: ${metric.formula}',
                  style: const TextStyle(
                    color: Color(0xffbac2de),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '• Yếu tố tác động chính: ${metric.mainFactors.join(", ")}',
                  style: const TextStyle(
                    color: Color(0xffbac2de),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '• Giới hạn kiểm thử: ${metric.limitations}',
                  style: const TextStyle(
                    color: Color(0xfff9e2af),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '• Trích dẫn nguồn: ${metric.references}',
                  style: const TextStyle(
                    color: Color(0xff94a3b8),
                    fontSize: 10.5,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // --- TAB 4: ĐA DẠNG TỪ VỰNG ---
  static Widget buildLexicalDiversityTab(TextProfileResult profile) {
    final div = profile.lexicalDiversity;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: buildMetricHighlightCard(
                  title: 'Type-Token Ratio (TTR)',
                  value: '${div.ttr}',
                  subtitle:
                      '${div.uniqueWordCount} từ / ${div.totalTokens} lượt từ',
                  color: DgnlHighlightPalette.tokenFocused.badgeDark,
                  icon: Icons.donut_large_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: buildMetricHighlightCard(
                  title: 'MATTR (Cửa sổ 25 từ)',
                  value: '${div.mattr}',
                  subtitle: 'Độ đa dạng trung bình trượt',
                  color: DgnlHighlightPalette.tokenCollocation.badgeDark,
                  icon: Icons.timeline_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: buildMetricHighlightCard(
                  title: 'Chỉ số MTLD',
                  value: '${div.mtld}',
                  subtitle: 'Độ dài chuỗi bảo toàn TTR 0.72',
                  color: DgnlHighlightPalette.tokenAllVocab.badgeDark,
                  icon: Icons.linear_scale_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: buildMetricHighlightCard(
                  title: 'Từ Học thuật (AWL)',
                  value: '${div.academicPercentage}%',
                  subtitle: '${div.academicWordCount} từ học thuật xuất hiện',
                  color: DgnlHighlightPalette.tokenB2.badgeDark,
                  icon: Icons.school_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0x14ffffff),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              div.ttrInterpretation,
              style: const TextStyle(
                color: Color(0xffcdd6f4),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Top Từ vựng Lặp lại nhiều nhất:',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final item in div.topRepeatedWords) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0x28ffffff),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${item.key} (${item.value})',
                              style: const TextStyle(
                                color: Color(0xff89dceb),
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Từ vựng Danh mục Học thuật (AWL):',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final aw in div.academicWords) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0x28f59e0b),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0x66f59e0b),
                              ),
                            ),
                            child: Text(
                              aw,
                              style: const TextStyle(
                                color: Color(0xfff59e0b),
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- TAB 5: CÚ PHÁP CÂU ---
  static Widget buildSyntacticComplexityTab(TextProfileResult profile) {
    final syn = profile.syntacticComplexity;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: buildMetricHighlightCard(
                  title: 'Độ dài Câu ngắn / vừa / dài',
                  value:
                      '${syn.shortSentences} / ${syn.mediumSentences} / ${syn.longSentences}',
                  subtitle: '< 12 từ / 12-25 từ / > 25 từ',
                  color: const Color(0xff89b4fa),
                  icon: Icons.bar_chart_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: buildMetricHighlightCard(
                  title: 'Câu Phức & Ghép-Phức',
                  value:
                      '${syn.complexSentenceCount + syn.compoundComplexSentenceCount}',
                  subtitle:
                      '${syn.simpleSentenceCount} câu đơn • ${syn.compoundSentenceCount} câu ghép',
                  color: const Color(0xffcba6f7),
                  icon: Icons.account_tree_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: buildMetricHighlightCard(
                  title: 'Cấu trúc Bị động',
                  value: '${syn.passiveVoiceCount}',
                  subtitle: 'Passive Voice trong đoạn',
                  color: const Color(0xfff59e0b),
                  icon: Icons.swap_horiz_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: buildMetricHighlightCard(
                  title: 'Mệnh đề Quan hệ',
                  value: '${syn.relativeClauseCount}',
                  subtitle: 'who, which, that, whose',
                  color: const Color(0xff86efac),
                  icon: Icons.link_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Các cấu trúc ngữ pháp cần lưu ý:',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (syn.challengingStructures.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0x10ffffff),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Không phát hiện câu văn quá dài (> 25 từ) hoặc cấu trúc ngữ pháp quá tải.',
                style: TextStyle(color: Color(0xff86efac), fontSize: 11.5),
              ),
            ),
          ] else ...[
            for (final item in syn.challengingStructures) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.arrow_right,
                      color: Color(0xfff59e0b),
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(
                          color: Color(0xffbac2de),
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  // --- TAB 6: BAO PHỦ & DẠY TRƯỚC ---
  static Widget buildCoverageTab(TextProfileResult profile) {
    final cov = profile.vocabularyCoverage;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: buildMetricHighlightCard(
                  title: 'Dải K1 (1–1000 từ)',
                  value: '${cov.k1Percent}%',
                  subtitle: 'Từ vựng cốt lõi A1–A2',
                  color: DgnlHighlightPalette.tokenA1.badgeDark,
                  icon: Icons.filter_1_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: buildMetricHighlightCard(
                  title: 'Dải K2 (1001–2000 từ)',
                  value: '${cov.k2Percent}%',
                  subtitle: 'Từ vựng trung cấp B1',
                  color: DgnlHighlightPalette.tokenB1.badgeDark,
                  icon: Icons.filter_2_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: buildMetricHighlightCard(
                  title: 'Dải K3 (2001–3000 từ)',
                  value: '${cov.k3Percent}%',
                  subtitle: 'Từ vựng trung cao B2',
                  color: DgnlHighlightPalette.tokenB2.badgeDark,
                  icon: Icons.filter_3_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: buildMetricHighlightCard(
                  title: 'Dải K4+ & Học thuật',
                  value: '${cov.k4PlusPercent}%',
                  subtitle: 'Từ nâng cao C1–C2 / AWL',
                  color: DgnlHighlightPalette.tokenC2.badgeDark,
                  icon: Icons.filter_4_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Row(
            children: [
              Icon(
                Icons.bookmark_added_outlined,
                color: Color(0xff86efac),
                size: 16,
              ),
              SizedBox(width: 6),
              Text(
                'Danh sách Từ vựng khuyến nghị Dạy trước (Pre-teach Vocabulary):',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (cov.preTeachWords.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0x10ffffff),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Văn bản sử dụng toàn bộ từ vựng cơ bản K1–K2, không có từ vựng B2+ cần dạy trước.',
                style: TextStyle(color: Color(0xff86efac), fontSize: 12),
              ),
            ),
          ] else ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final w in cov.preTeachWords) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x22ffffff),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: w.cefrLevel == 'C1' || w.cefrLevel == 'C2'
                            ? const Color(0xffa855f7)
                            : const Color(0xfff59e0b),
                        width: 1.1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          w.surface,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: w.cefrLevel == 'C1' || w.cefrLevel == 'C2'
                                ? const Color(0x55a855f7)
                                : const Color(0x55f59e0b),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            w.cefrLevel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  // --- TAB 7: KHUYẾN NGHỊ SƯ PHẠM ---
  static Widget buildRecommendationsTab(TextProfileResult profile) {
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      itemCount: profile.recommendations.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (ctx, idx) {
        final rec = profile.recommendations[idx];
        Color badgeColor = const Color(0xff89b4fa);
        if (rec.priority == 'high') {
          badgeColor = const Color(0xfff97316);
        } else if (rec.priority == 'medium') {
          badgeColor = const Color(0xfff59e0b);
        }

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0x18ffffff),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: badgeColor.withValues(alpha: 0.4),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      rec.priority.toUpperCase(),
                      style: TextStyle(
                        color: badgeColor,
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      rec.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                rec.description,
                style: const TextStyle(
                  color: Color(0xffcdd6f4),
                  fontSize: 11.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: const Color(0x14ffffff),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.arrow_forward,
                      size: 13,
                      color: Color(0xff86efac),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Hành động gợi ý: ${rec.actionableStep}',
                        style: const TextStyle(
                          color: Color(0xff86efac),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- TAB 8: CHUẨN ĐỀ THI ---
  static Widget buildExamProfilesTab(TextProfileResult profile) {
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      itemCount: profile.examProfiles.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (ctx, idx) {
        final ex = profile.examProfiles[idx];

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0x18ffffff),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x28ffffff)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${ex.examName} — ${ex.targetLevel}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2.5,
                    ),
                    decoration: BoxDecoration(
                      color: ex.overallFit.contains('tối ưu')
                          ? const Color(0x3386efac)
                          : const Color(0x3389b4fa),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: ex.overallFit.contains('tối ưu')
                            ? const Color(0xff86efac)
                            : const Color(0xff89b4fa),
                        width: 1.0,
                      ),
                    ),
                    child: Text(
                      ex.overallFit,
                      style: TextStyle(
                        color: ex.overallFit.contains('tối ưu')
                            ? const Color(0xff86efac)
                            : const Color(0xff89b4fa),
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '• Đọc hiểu: ${ex.readabilityFit}',
                style: const TextStyle(color: Color(0xffbac2de), fontSize: 11),
              ),
              Text(
                '• Từ vựng: ${ex.vocabularyFit}',
                style: const TextStyle(color: Color(0xffbac2de), fontSize: 11),
              ),
              Text(
                '• Cú pháp câu: ${ex.sentenceComplexityFit}',
                style: const TextStyle(color: Color(0xffbac2de), fontSize: 11),
              ),
              const SizedBox(height: 6),
              Text(
                'Ghi chú sư phạm: ${ex.notes}',
                style: const TextStyle(
                  color: Color(0xff94a3b8),
                  fontSize: 10.5,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
