import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:teaching_companion/core/theme/theme.dart';
import '../../domain/models/studio_board_models.dart';
import '../../domain/models/text_profile_models.dart';
import '../../services/profiler/text_profiler_service.dart';
import 'text_profiler_tab_views.dart';

class TextProfilerDialog extends StatefulWidget {
  final PdfDgnlPassage passage;
  final TextProfileResult profile;

  const TextProfilerDialog({
    super.key,
    required this.passage,
    required this.profile,
  });

  static Future<void> show(BuildContext context, PdfDgnlPassage passage) async {
    final profile =
        passage.textProfile ?? TextProfilerService.profile(passage.rawText);

    await showAppModalDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: const Color(0xcc000000),
      builder: (ctx) => TextProfilerDialog(passage: passage, profile: profile),
    );
  }

  @override
  State<TextProfilerDialog> createState() => _TextProfilerDialogState();
}

class _TextProfilerDialogState extends State<TextProfilerDialog> {
  int _activeTabIndex = 0;
  WordTokenInfo? _selectedWord;
  final Set<String> _expandedMetricIds = {};
  late final ScrollController _tabScrollController;

  @override
  void initState() {
    super.initState();
    _tabScrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabScrollController.dispose();
    super.dispose();
  }

  final List<({String label, IconData icon})> _tabs = const [
    (label: 'Tổng quan', icon: Icons.dashboard_outlined),
    (label: 'Từ vựng CEFR', icon: Icons.pie_chart),
    (label: 'Độ khó Đọc hiểu', icon: Icons.auto_stories_outlined),
    (label: 'Đa dạng Từ vựng', icon: Icons.donut_large_outlined),
    (label: 'Cú pháp Câu', icon: Icons.account_tree_outlined),
    (
      label: 'Bao phủ & Dạy trước',
      icon: Icons.playlist_add_check_circle_outlined,
    ),
    (label: 'Khuyến nghị Sư phạm', icon: Icons.lightbulb_outline),
    (label: 'Chuẩn Đề thi', icon: Icons.school_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final dialogWidth = math.min(size.width - 48, 1020.0);
    final dialogHeight = math.min(size.height - 48, 700.0);
    final profile = widget.profile;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: dialogWidth,
          height: dialogHeight,
          decoration: BoxDecoration(
            color: const Color(0xf8111a15),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0x5589b4fa), width: 1.4),
            boxShadow: const [
              BoxShadow(
                color: Color(0xee000000),
                blurRadius: 28,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildHeader(profile),
              _buildTabBar(),
              const Divider(color: Color(0x28ffffff), height: 1),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: AnimatedSwitcher(
                    duration: AppMotion.duration(context, milliseconds: 180),
                    switchInCurve: AppMotion.enterCurve,
                    switchOutCurve: AppMotion.exitCurve,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.015, 0),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: KeyedSubtree(
                      key: ValueKey(_activeTabIndex),
                      child: _buildTabContent(profile),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(TextProfileResult profile) {
    Color levelColor = const Color(0xfff59e0b);
    if (profile.dominantCefrLevel == 'C1' ||
        profile.dominantCefrLevel == 'C2') {
      levelColor = const Color(0xffa855f7);
    } else if (profile.dominantCefrLevel == 'B1') {
      levelColor = const Color(0xff3b82f6);
    } else if (profile.dominantCefrLevel == 'A2') {
      levelColor = const Color(0xff14b8a6);
    } else if (profile.dominantCefrLevel == 'A1') {
      levelColor = const Color(0xff22c55e);
    }

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
                    const Text(
                      'Hồ sơ Độ khó Ngữ liệu Tiếng Anh',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: levelColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: levelColor, width: 1.1),
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
                  '${profile.statistics.totalWords} từ • ${profile.statistics.totalSentences} câu • Độ dài câu TB ${profile.statistics.avgSentenceLength} từ • 100% Offline Engine',
                  style: const TextStyle(
                    color: Color(0xffa6adc8),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70, size: 20),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Đóng',
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: const Color(0x0cffffff),
      height: 42,
      child: AnimatedBuilder(
        animation: _tabScrollController,
        builder: (context, _) {
          final hasClients = _tabScrollController.hasClients;
          final maxExtent = hasClients
              ? _tabScrollController.position.maxScrollExtent
              : 0.0;
          final currentOffset = hasClients ? _tabScrollController.offset : 0.0;
          final canScrollLeft = hasClients && currentOffset > 4.0;
          final canScrollRight =
              hasClients && maxExtent > 0 && currentOffset < maxExtent - 4.0;

          return Row(
            children: [
              if (canScrollLeft)
                _buildTabScrollArrow(
                  icon: Icons.chevron_left_rounded,
                  tooltip: 'Cuộn sang trái',
                  onPressed: () {
                    _tabScrollController.animateTo(
                      math.max(0.0, _tabScrollController.offset - 180.0),
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                    );
                  },
                ),
              Expanded(
                child: Listener(
                  onPointerSignal: (pointerSignal) {
                    if (pointerSignal is PointerScrollEvent &&
                        _tabScrollController.hasClients) {
                      final scrollDelta = pointerSignal.scrollDelta.dy != 0
                          ? pointerSignal.scrollDelta.dy
                          : pointerSignal.scrollDelta.dx;
                      final target = (_tabScrollController.offset + scrollDelta)
                          .clamp(
                            0.0,
                            _tabScrollController.position.maxScrollExtent,
                          );
                      _tabScrollController.jumpTo(target);
                    }
                  },
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context).copyWith(
                      dragDevices: {
                        PointerDeviceKind.touch,
                        PointerDeviceKind.mouse,
                        PointerDeviceKind.trackpad,
                        PointerDeviceKind.stylus,
                      },
                    ),
                    child: ListView.builder(
                      controller: _tabScrollController,
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _tabs.length,
                      itemBuilder: (ctx, idx) {
                        final isSelected = _activeTabIndex == idx;
                        final t = _tabs[idx];
                        return AppPressable(
                          onTap: () {
                            setState(() => _activeTabIndex = idx);
                            _scrollToTab(idx);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: isSelected
                                      ? const Color(0xff89b4fa)
                                      : Colors.transparent,
                                  width: 2.2,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  t.icon,
                                  size: 14,
                                  color: isSelected
                                      ? const Color(0xff89b4fa)
                                      : const Color(0xffa6adc8),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  t.label,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : const Color(0xffa6adc8),
                                    fontSize: 12,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              if (canScrollRight)
                _buildTabScrollArrow(
                  icon: Icons.chevron_right_rounded,
                  tooltip: 'Cuộn sang phải',
                  onPressed: () {
                    _tabScrollController.animateTo(
                      math.min(
                        _tabScrollController.position.maxScrollExtent,
                        _tabScrollController.offset + 180.0,
                      ),
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTabScrollArrow({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            width: 28,
            height: 42,
            alignment: Alignment.center,
            color: const Color(0x33000000),
            child: Icon(icon, color: Colors.white70, size: 20),
          ),
        ),
      ),
    );
  }

  void _scrollToTab(int index) {
    if (!_tabScrollController.hasClients) return;
    final estimatedTabOffset = index * 125.0;
    final viewportWidth = _tabScrollController.position.viewportDimension;
    final target = (estimatedTabOffset - (viewportWidth / 2) + 60.0).clamp(
      0.0,
      _tabScrollController.position.maxScrollExtent,
    );
    _tabScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildTabContent(TextProfileResult profile) {
    switch (_activeTabIndex) {
      case 0:
        return _buildOverviewTab(profile);
      case 1:
        return _buildCefrVocabularyTab(profile);
      case 2:
        return TextProfilerTabViews.buildReadabilityTab(
          profile,
          _expandedMetricIds,
          (id) => setState(() {
            if (_expandedMetricIds.contains(id)) {
              _expandedMetricIds.remove(id);
            } else {
              _expandedMetricIds.add(id);
            }
          }),
        );
      case 3:
        return TextProfilerTabViews.buildLexicalDiversityTab(profile);
      case 4:
        return TextProfilerTabViews.buildSyntacticComplexityTab(profile);
      case 5:
        return TextProfilerTabViews.buildCoverageTab(profile);
      case 6:
        return TextProfilerTabViews.buildRecommendationsTab(profile);
      case 7:
        return TextProfilerTabViews.buildExamProfilesTab(profile);
      default:
        return const SizedBox.shrink();
    }
  }

  // --- TAB 1: TỔNG QUAN ---
  Widget _buildOverviewTab(TextProfileResult profile) {
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
              widget.passage.rawText,
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

  // --- TAB 2: TỪ VỰNG CEFR ---
  Widget _buildCefrVocabularyTab(TextProfileResult profile) {
    const levelColors = <String, Color>{
      'A1': Color(0xff22c55e),
      'A2': Color(0xff14b8a6),
      'B1': Color(0xff3b82f6),
      'B2': Color(0xfff59e0b),
      'C1': Color(0xfff97316),
      'C2': Color(0xffa855f7),
      'Unknown': Color(0xff94a3b8),
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tỷ lệ Phân bố Khung CEFR 6 Cấp độ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    height: 22,
                    child: Row(
                      children: [
                        for (final entry
                            in profile.cefrPercentages.entries) ...[
                          if (entry.value > 0)
                            Expanded(
                              flex: (entry.value * 10).round(),
                              child: Container(
                                color: levelColors[entry.key] ?? Colors.grey,
                                alignment: Alignment.center,
                                child: Text(
                                  entry.value >= 8 ? entry.key : '',
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                for (final lvl in [
                  'A1',
                  'A2',
                  'B1',
                  'B2',
                  'C1',
                  'C2',
                  'Unknown',
                ]) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: levelColors[lvl],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          lvl == 'Unknown'
                              ? 'Chưa định danh (Proper/Rare)'
                              : 'Cấp độ $lvl',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11.5,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${profile.cefrCounts[lvl] ?? 0} từ (${profile.cefrPercentages[lvl] ?? 0}%)',
                          style: TextStyle(
                            color: levelColors[lvl],
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0x10ffffff),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Lưu ý: Từ chưa có trong từ điển không mặc định gán là C1 hay C2. Từ có thể đổi cấp độ theo ngữ cảnh từ loại (Noun vs Verb).',
                    style: TextStyle(
                      color: Color(0xff94a3b8),
                      fontSize: 10.5,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 18),
        const VerticalDivider(color: Color(0x28ffffff), width: 1),
        const SizedBox(width: 18),
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.touch_app_outlined,
                    color: Color(0xff89b4fa),
                    size: 14,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Khám phá từ vựng (Nhấp vào từ để tra cứu):',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0x0cffffff),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0x18ffffff)),
                  ),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Wrap(
                      spacing: 5,
                      runSpacing: 6,
                      children: [
                        for (final t in profile.tokens) ...[
                          InkWell(
                            onTap: () => setState(() => _selectedWord = t),
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _selectedWord == t
                                    ? Colors.white
                                    : (levelColors[t.cefrLevel] ?? Colors.grey)
                                          .withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color:
                                      levelColors[t.cefrLevel] ?? Colors.grey,
                                  width: _selectedWord == t ? 1.5 : 0.8,
                                ),
                              ),
                              child: Text(
                                t.surface,
                                style: TextStyle(
                                  color: _selectedWord == t
                                      ? Colors.black
                                      : (levelColors[t.cefrLevel] ??
                                            Colors.white),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              if (_selectedWord != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0x28ffffff),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color:
                          levelColors[_selectedWord!.cefrLevel] ?? Colors.grey,
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedWord!.surface,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Nguyên mẫu: ${_selectedWord!.lemma} • ${_selectedWord!.pos}',
                            style: const TextStyle(
                              color: Color(0xffa6adc8),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  (levelColors[_selectedWord!.cefrLevel] ??
                                          Colors.grey)
                                      .withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'CEFR ${_selectedWord!.cefrLevel}',
                              style: TextStyle(
                                color:
                                    levelColors[_selectedWord!.cefrLevel] ??
                                    Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Dải tần: ${_selectedWord!.frequencyBand} • ${_selectedWord!.syllables} âm tiết',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
