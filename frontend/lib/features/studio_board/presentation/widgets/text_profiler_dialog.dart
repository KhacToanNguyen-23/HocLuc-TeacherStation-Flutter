import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:teaching_companion/core/theme/theme.dart';
import '../../domain/models/studio_board_models.dart';
import '../../domain/models/text_profile_models.dart';
import '../../services/profiler/dictionary_enrichment_controller.dart';
import 'text_profiler_dictionary_panel.dart';
import 'text_profiler_advanced_summary.dart';
import 'text_profiler_dialog_header.dart';
import 'text_profiler_overview_tab.dart';
import 'text_profiler_tab_views.dart';

class TextProfilerDialog extends StatefulWidget {
  final PdfDgnlPassage passage;
  final TextProfileResult profile;
  final DictionaryEnrichmentController? enrichmentController;

  const TextProfilerDialog({
    super.key,
    required this.passage,
    required this.profile,
    this.enrichmentController,
  });

  static Future<void> show(
    BuildContext context,
    PdfDgnlPassage passage, {
    DictionaryEnrichmentController? enrichmentController,
  }) async {
    final controller =
        enrichmentController ?? DictionaryEnrichmentController.instance;
    final profile = controller.profileAndEnrich(passage);

    try {
      await showAppModalDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierColor: const Color(0xcc000000),
        builder: (ctx) => TextProfilerDialog(
          passage: passage,
          profile: profile,
          enrichmentController: controller,
        ),
      );
    } finally {
      controller.deactivate(passage.id);
    }
  }

  @override
  State<TextProfilerDialog> createState() => _TextProfilerDialogState();
}

class _TextProfilerDialogState extends State<TextProfilerDialog> {
  int _activeTabIndex = 0;
  WordTokenInfo? _selectedWord;
  final Set<String> _expandedMetricIds = {};
  late final ScrollController _tabScrollController;

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

  DictionaryEnrichmentController get _dictionaryController =>
      widget.enrichmentController ?? DictionaryEnrichmentController.instance;

  @override
  void initState() {
    super.initState();
    _tabScrollController = ScrollController();
    if (widget.profile.tokens.isNotEmpty) {
      _selectedWord = widget.profile.tokens.first;
    }
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

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Container(
        width: 1040,
        height: 680,
        decoration: BoxDecoration(
          color: const Color(0xf8111a15),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0x5589b4fa), width: 1.4),
          boxShadow: const [
            BoxShadow(
              color: Color(0xee000000),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            TextProfilerDialogHeader(
              profile: profile,
              onClose: () => Navigator.of(context).pop(),
            ),
            const Divider(color: Color(0x28ffffff), height: 1),
            _buildTabBar(),
            const Divider(color: Color(0x28ffffff), height: 1),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: _buildTabContent(profile),
              ),
            ),
          ],
        ),
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
                  tooltip: 'Cuộn tab sang trái',
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
                        return InkWell(
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
        return TextProfilerOverviewTab(
          profile: profile,
          rawText: widget.passage.rawText,
        );
      case 1:
        return _buildCefrVocabularyTab(profile);
      case 2:
        return Column(
          children: [
            TextProfilerAdvancedSummary(
              profile: profile,
              passageId: widget.passage.id,
              controller: _dictionaryController,
            ),
            const SizedBox(height: 10),
            Expanded(
              child: TextProfilerTabViews.buildReadabilityTab(
                profile,
                _expandedMetricIds,
                (id) => setState(() {
                  if (_expandedMetricIds.contains(id)) {
                    _expandedMetricIds.remove(id);
                  } else {
                    _expandedMetricIds.add(id);
                  }
                }),
              ),
            ),
          ],
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

  // --- TAB 2: TỪ VỰNG CEFR ---
  Widget _buildCefrVocabularyTab(TextProfileResult profile) {
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
                                color: DgnlHighlightPalette.tokenForLevel(
                                  entry.key,
                                ).badgeDark,
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
                const SizedBox(height: 14),
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
                            color: DgnlHighlightPalette.tokenForLevel(
                              lvl,
                            ).badgeDark,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                lvl == 'Unknown'
                                    ? 'Chưa định danh (Proper/Rare)'
                                    : 'Cấp độ $lvl',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11.5,
                                ),
                              ),
                              if (lvl == 'Unknown' &&
                                  (profile.recognizedUnratedCount > 0 ||
                                      profile.notInLexiconCount > 0))
                                Text(
                                  'Đã nhận diện: ${profile.recognizedUnratedCount} • Chưa có mục từ: ${profile.notInLexiconCount}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xff94a3b8),
                                    fontSize: 9,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${profile.cefrCounts[lvl] ?? 0} từ (${profile.cefrPercentages[lvl] ?? 0}%)',
                          style: TextStyle(
                            color: DgnlHighlightPalette.tokenForLevel(
                              lvl,
                            ).badgeDark,
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
                const SizedBox(height: 10),
                TextProfilerAdvancedSummary(
                  profile: profile,
                  passageId: widget.passage.id,
                  controller: _dictionaryController,
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
                  Expanded(
                    child: Text(
                      'Khám phá từ vựng (Nhấp vào từ để tra cứu):',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: _selectedWord == null ? 1 : 2,
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
                                  onTap: () {
                                    setState(() => _selectedWord = t);
                                    if (t.cefrLevel == 'Unknown' &&
                                        _dictionaryController.entryFor(
                                              widget.passage.id,
                                              t.lemma,
                                            ) ==
                                            null) {
                                      unawaited(
                                        _dictionaryController.loadCachedEntry(
                                          widget.passage.id,
                                          t.lemma,
                                        ),
                                      );
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(4),
                                  child: AnimatedBuilder(
                                    animation: _dictionaryController,
                                    builder: (context, _) {
                                      final hasApiEntry = _dictionaryController
                                          .hasApiDictionaryEntry(
                                            widget.passage.id,
                                            t,
                                          );
                                      final tokenObj =
                                          DgnlHighlightPalette.tokenForLevel(
                                            t.cefrLevel,
                                          );
                                      final tokenBadgeColor =
                                          tokenObj.badgeDark;
                                      final tokenStrokeColor = tokenObj.stroke;
                                      final tokenForegroundColor =
                                          tokenObj.foreground;
                                      return Container(
                                        key: hasApiEntry
                                            ? const Key(
                                                'api-dictionary-entry-token',
                                              )
                                            : null,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 5,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _selectedWord == t
                                              ? Colors.white
                                              : tokenObj.fill.withValues(
                                                  alpha: 0.20,
                                                ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          border: Border.all(
                                            color: _selectedWord == t
                                                ? tokenStrokeColor
                                                : tokenStrokeColor.withValues(
                                                    alpha: 0.85,
                                                  ),
                                            width: _selectedWord == t
                                                ? 1.5
                                                : 0.9,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              t.surface,
                                              style: TextStyle(
                                                color: _selectedWord == t
                                                    ? tokenForegroundColor
                                                    : tokenBadgeColor,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            if (t.isRecognizedUnrated) ...[
                                              const SizedBox(width: 3),
                                              const Tooltip(
                                                message:
                                                    'Recognized offline; CEFR level unavailable',
                                                child: Icon(
                                                  Icons.menu_book_outlined,
                                                  key: Key(
                                                    'recognized-unrated-marker',
                                                  ),
                                                  size: 11,
                                                  color: Color(0xff94a3b8),
                                                ),
                                              ),
                                            ],
                                            if (hasApiEntry) ...[
                                              const SizedBox(width: 3),
                                              const Tooltip(
                                                message:
                                                    'Dictionary metadata found; CEFR and difficulty unchanged',
                                                child: Icon(
                                                  Icons.menu_book_outlined,
                                                  key: Key(
                                                    'dictionary-entry-marker',
                                                  ),
                                                  size: 11,
                                                  color: Color(0xff22c55e),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      );
                                    },
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
                      AnimatedBuilder(
                        animation: _dictionaryController,
                        builder: (context, _) => Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0x28ffffff),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: DgnlHighlightPalette.tokenForLevel(
                                _selectedWord!.cefrLevel,
                              ).stroke,
                              width: 1.2,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _selectedWord!.surface,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          'Lemma: ${_selectedWord!.lemma} \u2022 ${_selectedWord!.pos}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Color(0xffa6adc8),
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: DgnlHighlightPalette.tokenForLevel(
                                        _selectedWord!.cefrLevel,
                                      ).fill.withValues(alpha: 0.25),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color:
                                            DgnlHighlightPalette.tokenForLevel(
                                              _selectedWord!.cefrLevel,
                                            ).stroke.withValues(alpha: 0.6),
                                      ),
                                    ),
                                    child: Text(
                                      'CEFR ${_selectedWord!.cefrLevel}',
                                      style: TextStyle(
                                        color:
                                            DgnlHighlightPalette.tokenForLevel(
                                              _selectedWord!.cefrLevel,
                                            ).badgeDark,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (_selectedWord!.isRecognizedUnrated) ...[
                                const SizedBox(height: 3),
                                const Tooltip(
                                  message:
                                      'Recognized offline; CEFR level unavailable',
                                  child: Text(
                                    'Recognized offline',
                                    key: Key(
                                      'recognized-unrated-detail-marker',
                                    ),
                                    style: TextStyle(
                                      color: Color(0xff94a3b8),
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                              if (_dictionaryController.hasApiDictionaryEntry(
                                widget.passage.id,
                                _selectedWord!,
                              )) ...[
                                const SizedBox(height: 3),
                                const Text(
                                  'Dictionary metadata found; CEFR remains Unknown',
                                  key: Key('dictionary-metadata-only-label'),
                                  style: TextStyle(
                                    color: Color(0xff22c55e),
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 2),
                              Text(
                                'Band: ${_selectedWord!.frequencyBand} \u2022 ${_selectedWord!.syllables} syllables',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_selectedWord!.cefrLevel == 'Unknown') ...[
                        const SizedBox(height: 8),
                        Expanded(
                          flex: 3,
                          child: SingleChildScrollView(
                            key: const Key('dictionary-details-scroll'),
                            physics: const BouncingScrollPhysics(),
                            child: AnimatedBuilder(
                              animation: _dictionaryController,
                              builder: (context, _) =>
                                  TextProfilerDictionaryPanel(
                                    token: _selectedWord!,
                                    passageId: widget.passage.id,
                                    controller: _dictionaryController,
                                  ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
