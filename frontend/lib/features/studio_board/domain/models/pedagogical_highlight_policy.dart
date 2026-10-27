import 'package:flutter/foundation.dart';
import 'studio_board_models.dart';

/// Centralized pedagogical highlighting policy for PDF vocabulary and grammar scanning.
///
/// Refines scanning highlights to prioritize pedagogically valuable targets (academic vocabulary,
/// B2-C2 vocabulary, collocations, grammar structures) while suppressing low-level noise (A1/A2,
/// common function words, excessive repetitions) by default.
@immutable
class PedagogicalHighlightPolicy {
  /// Whether A1 and A2 vocabulary are hidden from PDF highlighting by default.
  final bool hideA1A2ByDefault;

  /// Whether B1 words are highlighted selectively (only when academic, pre-teach, or key domain terms).
  final bool selectiveB1Highlighting;

  /// Whether academic vocabulary (AWL) is prioritized regardless of CEFR level.
  final bool prioritizeAcademicVocabulary;

  /// Whether meaningful collocations and phrasal expressions are prioritized.
  final bool prioritizeCollocations;

  /// Whether grammar structures worth explaining in a lesson are prioritized.
  final bool prioritizeImportantGrammar;

  /// Optional maximum number of visual highlights per passage to prevent visual noise.
  /// Does NOT truncate detected data in statistics or text profiler.
  final int? maxHighlightsPerPassage;

  /// Teacher override to reveal all detected vocabulary across all CEFR levels.
  final bool showAllVocabulary;

  /// Teacher toggle to reveal A1/A2 vocabulary on the document.
  final bool showA1A2;

  /// Maximum occurrences to highlight for the exact same lemma/term per passage in default mode.
  final int maxOccurrencesPerTerm;

  const PedagogicalHighlightPolicy({
    this.hideA1A2ByDefault = true,
    this.selectiveB1Highlighting = true,
    this.prioritizeAcademicVocabulary = true,
    this.prioritizeCollocations = true,
    this.prioritizeImportantGrammar = true,
    this.maxHighlightsPerPassage,
    this.showAllVocabulary = false,
    this.showA1A2 = false,
    this.maxOccurrencesPerTerm = 2,
  });

  /// Sensible default policy: hides A1/A2, selectively filters B1, prioritizes AWL/Collocations/Grammar.
  static const PedagogicalHighlightPolicy defaultPolicy =
      PedagogicalHighlightPolicy();

  /// Teacher override: shows all vocabulary (A1-C2) without filtering.
  static const PedagogicalHighlightPolicy allVocabulary =
      PedagogicalHighlightPolicy(
        hideA1A2ByDefault: false,
        selectiveB1Highlighting: false,
        showAllVocabulary: true,
        showA1A2: true,
      );

  PedagogicalHighlightPolicy copyWith({
    bool? hideA1A2ByDefault,
    bool? selectiveB1Highlighting,
    bool? prioritizeAcademicVocabulary,
    bool? prioritizeCollocations,
    bool? prioritizeImportantGrammar,
    int? maxHighlightsPerPassage,
    bool? showAllVocabulary,
    bool? showA1A2,
    int? maxOccurrencesPerTerm,
  }) {
    return PedagogicalHighlightPolicy(
      hideA1A2ByDefault: hideA1A2ByDefault ?? this.hideA1A2ByDefault,
      selectiveB1Highlighting:
          selectiveB1Highlighting ?? this.selectiveB1Highlighting,
      prioritizeAcademicVocabulary:
          prioritizeAcademicVocabulary ?? this.prioritizeAcademicVocabulary,
      prioritizeCollocations:
          prioritizeCollocations ?? this.prioritizeCollocations,
      prioritizeImportantGrammar:
          prioritizeImportantGrammar ?? this.prioritizeImportantGrammar,
      maxHighlightsPerPassage:
          maxHighlightsPerPassage ?? this.maxHighlightsPerPassage,
      showAllVocabulary: showAllVocabulary ?? this.showAllVocabulary,
      showA1A2: showA1A2 ?? this.showA1A2,
      maxOccurrencesPerTerm:
          maxOccurrencesPerTerm ?? this.maxOccurrencesPerTerm,
    );
  }

  /// Determines whether a single span qualifies for visual highlight under this policy.
  bool isEligibleForHighlight(PdfDgnlHighlightSpan span) {
    if (span.category == 'grammar') {
      return prioritizeImportantGrammar;
    }

    if (span.category == 'collocation') {
      return prioritizeCollocations;
    }

    if (span.category == 'vocabulary') {
      // Exclude function words, numbers, and proper nouns from default visual highlights
      if (span.isFunctionWord || span.isNumber || span.isProperNoun) {
        return false;
      }

      // Teacher override to show all vocabulary
      if (showAllVocabulary) {
        return true;
      }

      // Teacher override for A1/A2
      if (showA1A2 && (span.level == 'A1' || span.level == 'A2')) {
        return true;
      }

      // Academic vocabulary is prioritized independently of CEFR level
      if (prioritizeAcademicVocabulary && span.isAcademic) {
        return true;
      }

      final level = span.level.toUpperCase();

      // A1 and A2 words are hidden by default
      if (hideA1A2ByDefault && (level == 'A1' || level == 'A2')) {
        return false;
      }

      // B1 words are highlighted selectively
      if (level == 'B1') {
        if (!selectiveB1Highlighting) return true;
        return span.isAcademic || span.isPreTeach || span.isPedagogical;
      }

      // B2, C1, C2 words are strong candidates
      if (level == 'B2' || level == 'C1' || level == 'C2') {
        return true;
      }

      // Unknown vocabulary: only if marked as pre-teach or pedagogical target
      if (level == 'Unknown') {
        return span.isPreTeach || span.isPedagogical;
      }
    }

    return true;
  }

  /// Filters a list of spans according to this policy, preventing repetitive visual noise
  /// and respecting [maxHighlightsPerPassage] by pedagogical priority ranking.
  List<PdfDgnlHighlightSpan> filterSpans(List<PdfDgnlHighlightSpan> spans) {
    final eligible = spans.where(isEligibleForHighlight).toList();

    // Prevent duplicate clutter: limit occurrences of identical lemmas
    final termOccurrences = <String, int>{};
    final deduplicated = <PdfDgnlHighlightSpan>[];

    for (final s in eligible) {
      if (s.category == 'vocabulary' && !showAllVocabulary) {
        final key = (s.lemma ?? s.text).toLowerCase().trim();
        final count = termOccurrences[key] ?? 0;
        if (count >= maxOccurrencesPerTerm) {
          continue; // Skip excess occurrences of identical term
        }
        termOccurrences[key] = count + 1;
      }
      deduplicated.add(s);
    }

    if (maxHighlightsPerPassage != null &&
        deduplicated.length > maxHighlightsPerPassage!) {
      deduplicated.sort(
        (a, b) => _priorityScore(b).compareTo(_priorityScore(a)),
      );
      final topSpans = deduplicated.take(maxHighlightsPerPassage!).toList();
      topSpans.sort((a, b) {
        final aY =
            a.normalizedRects.isNotEmpty ? a.normalizedRects.first.top : 0.0;
        final bY =
            b.normalizedRects.isNotEmpty ? b.normalizedRects.first.top : 0.0;
        return aY.compareTo(bY);
      });
      return topSpans;
    }

    return deduplicated;
  }

  int _priorityScore(PdfDgnlHighlightSpan s) {
    int score = 0;
    if (s.isAcademic) score += 60;
    if (s.isPreTeach) score += 50;
    if (s.category == 'collocation') score += 40;
    if (s.category == 'grammar') score += 35;
    if (s.level == 'C2') score += 30;
    if (s.level == 'C1') score += 25;
    if (s.level == 'B2') score += 20;
    if (s.level == 'B1') score += 15;
    return score;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PedagogicalHighlightPolicy &&
          runtimeType == other.runtimeType &&
          hideA1A2ByDefault == other.hideA1A2ByDefault &&
          selectiveB1Highlighting == other.selectiveB1Highlighting &&
          prioritizeAcademicVocabulary ==
              other.prioritizeAcademicVocabulary &&
          prioritizeCollocations == other.prioritizeCollocations &&
          prioritizeImportantGrammar == other.prioritizeImportantGrammar &&
          maxHighlightsPerPassage == other.maxHighlightsPerPassage &&
          showAllVocabulary == other.showAllVocabulary &&
          showA1A2 == other.showA1A2 &&
          maxOccurrencesPerTerm == other.maxOccurrencesPerTerm;

  @override
  int get hashCode => Object.hash(
    hideA1A2ByDefault,
    selectiveB1Highlighting,
    prioritizeAcademicVocabulary,
    prioritizeCollocations,
    prioritizeImportantGrammar,
    maxHighlightsPerPassage,
    showAllVocabulary,
    showA1A2,
    maxOccurrencesPerTerm,
  );
}
