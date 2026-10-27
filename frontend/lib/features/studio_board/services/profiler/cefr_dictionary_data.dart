import '../../domain/models/offline_lexeme.dart';
import 'awl_word_list.dart';
import 'daily_life_vocabulary.dart';
import 'generated_cefr_source_words.dart';
import 'lemmatization_engine.dart';
import 'text_tokenizer.dart';

/// Lightweight static lexical database for CEFR A1–C2 and AWL classification.
/// Implements a strict 4-tier lookup order with OfflineLexeme abstraction:
/// 1. Exact-form match first (preserves specific forms like 'bitterness', 'bitterly' B2)
/// 2. Safe inflection rules (noodles -> noodle, medications -> medication, created -> create)
/// 3. Curated derivations (hyphenated compounds, -ly adverbs)
/// 4. Unassigned fallback for async API enrichment
class CefrDictionaryData {
  /// Coxhead AWL 570 base headwords.
  static final Set<String> coxheadAwlHeadwords = Set<String>.unmodifiable(
    coxheadAwlSublists.keys,
  );

  /// All single-token Coxhead AWL family forms.
  static final Set<String> academicWordList = Set<String>.unmodifiable(
    coxheadAwlFamilyLevels.keys,
  );

  /// Estimated academic difficulty tier based on AWL sublist frequency.
  /// This is a teaching metric, not an official CEFR assignment.
  static String? lookupAcademicMetricLevel(String lemma) {
    final word = lemma.toLowerCase().trim().replaceAll('-', '');
    final sublist = coxheadAwlFamilyLevels[word];
    if (sublist == null) return null;
    return sublist <= 5 ? 'B2' : 'C1';
  }

  /// Published source projection used by the synchronous offline profiler.
  static const Map<String, String> wordToCefr = generatedCefrSourceWords;
  static const Set<String> wordToCefrHeadwords = generatedCefrSourceHeadwords;
  static const Set<String> recognizedUnratedWords =
      generatedRecognizedUnratedWords;

  /// True for recognized lexical entries without a supported CEFR label.
  /// These entries remain in the Unknown CEFR group offline.
  static bool isRecognizedUnrated(String word) {
    final lexeme = lookupLexeme(word);
    return lexeme != null && lexeme.isUnrated;
  }

  /// Returns the CEFR level for a lemma. Defaults to null if not catalogued.
  static String? lookupCefr(String lemma) {
    return lookupLexeme(lemma)?.cefrLevel;
  }

  /// Maps word to frequency band (K1: 1-1000, K2: 1001-2000, K3: 2001-3000, K4+: 3001+, Off-list)
  static String getFrequencyBand(String lemma, String cefrLevel) {
    if (cefrLevel == 'A1' || cefrLevel == 'A2') return 'K1';
    if (cefrLevel == 'B1') return 'K2';
    if (cefrLevel == 'B2') return 'K3';
    if (cefrLevel == 'C1' || cefrLevel == 'C2') return 'K4+';
    if (academicWordList.contains(lemma)) return 'K3';
    return 'Off-list';
  }

  /// Resolves an offline lexeme following a strict 4-tier lookup precedence:
  /// (1) Exact-form match first
  /// (2) Safe inflection rules
  /// (3) Curated derivations
  /// (4) Unassigned fallback (returns null)
  static OfflineLexeme? lookupLexeme(String word) {
    final normalized = TextTokenizer.normalizeCompoundLemma(word);
    if (normalized.isEmpty) return null;

    // -------------------------------------------------------------------------
    // Tier 0: Common contractions & clitics resolution
    // (didn't -> do, they're -> they, we've -> we, can't -> can, it's -> it)
    // -------------------------------------------------------------------------
    final contractionMatch = LemmatizationEngine.resolveContraction(normalized);
    if (contractionMatch != null) return contractionMatch;

    // -------------------------------------------------------------------------
    // Tier 1: Exact-form match first
    // Preserves specific forms like 'bitterness', 'bitterly' (B2), 'medication'
    // -------------------------------------------------------------------------
    final exactMatch = _matchExact(normalized);
    if (exactMatch != null) return exactMatch;

    // Hyphenated compound resolution (Tier 3)
    if (normalized.contains('-')) {
      return _matchCompound(normalized);
    }

    // -------------------------------------------------------------------------
    // Tier 2: Safe inflection rules
    // (noodles -> noodle, medications -> medication, created -> create)
    // -------------------------------------------------------------------------
    for (final candidate in _safeInflectionCandidates(normalized)) {
      final inflectedMatch = _matchExact(candidate);
      if (inflectedMatch != null) {
        return inflectedMatch;
      }
    }

    // -------------------------------------------------------------------------
    // Tier 3: Curated derivations
    // (-ly -> adjective, -ness -> base, etc.)
    // -------------------------------------------------------------------------
    for (final candidate in _curatedDerivationCandidates(normalized)) {
      final derivationMatch = _matchExact(candidate);
      if (derivationMatch != null) {
        return derivationMatch;
      }
    }

    // AWL family off-list fallback (for derived forms not in CEFR-J)
    final familySublist = coxheadAwlFamilyLevels[normalized];
    if (familySublist != null) {
      final metricLevel = familySublist <= 5 ? 'B2' : 'C1';
      return OfflineLexeme(
        headword: normalized,
        cefrLevel: metricLevel,
        isRecognized: true,
        isAwlHeadword: false,
        awlSublist: familySublist,
        frequencyBand: 'K3',
        provenance: 'Coxhead AWL Family',
      );
    }

    // -------------------------------------------------------------------------
    // Tier 4: Unassigned fallback
    // Returns null to queue for online API enrichment
    // -------------------------------------------------------------------------
    return null;
  }

  /// Exact-form catalog lookup without stripping suffixes.
  /// Keeps AWL 570 base headwords separate from family derivatives.
  static OfflineLexeme? _matchExact(String word) {
    final clean = word.toLowerCase();

    // 1. Check curated daily-life vocabulary
    final cefr = wordToCefr[clean];
    final daily = DailyLifeVocabulary.get(clean);
    if (daily != null) {
      if (daily.cefrLevel != null) return daily;
      if (cefr != null) {
        return daily.copyWith(
          cefrLevel: cefr,
          frequencyBand: getFrequencyBand(clean, cefr),
        );
      }
      return daily;
    }

    // 2. Check Coxhead AWL 570 base headwords
    final awlSublist = coxheadAwlSublists[clean];
    final isAwlHead = awlSublist != null;

    // 3. Check published CEFR dictionary
    if (cefr != null) {
      final band = getFrequencyBand(clean, cefr);
      return OfflineLexeme(
        headword: clean,
        cefrLevel: cefr,
        isRecognized: true,
        isAwlHeadword: isAwlHead,
        awlSublist: awlSublist ?? coxheadAwlFamilyLevels[clean],
        frequencyBand: band,
        provenance: 'CEFR-J 1.5',
      );
    }

    // 4. Check AWL base headwords without CEFR
    if (isAwlHead) {
      final metricLevel = awlSublist <= 5 ? 'B2' : 'C1';
      return OfflineLexeme(
        headword: clean,
        cefrLevel: metricLevel,
        isRecognized: true,
        isAwlHeadword: true,
        awlSublist: awlSublist,
        frequencyBand: 'K3',
        provenance: 'Coxhead AWL',
      );
    }

    // 5. Check recognized unrated words
    if (recognizedUnratedWords.contains(clean)) {
      return OfflineLexeme(
        headword: clean,
        cefrLevel: null,
        isRecognized: true,
        frequencyBand: 'Off-list',
        provenance: 'HocLuc Curated Unrated',
      );
    }

    return null;
  }

  /// Produces candidate base forms strictly under inflectional rules.
  static List<String> _safeInflectionCandidates(String word) {
    final candidates = <String>[];
    void add(String val) {
      if (val.isNotEmpty && val != word && !candidates.contains(val)) {
        candidates.add(val);
      }
    }

    // Possessive suffix stripping fallback:
    // "children's" -> "children" -> "child", "students'" -> "students" -> "student", "teacher's" -> "teacher"
    final unpossessed = LemmatizationEngine.stripPossessive(word);
    if (unpossessed != null && unpossessed.isNotEmpty) {
      add(unpossessed);
      final unpossessedLemma = TextTokenizer.normalizeLemma(unpossessed);
      if (unpossessedLemma.isNotEmpty) {
        add(unpossessedLemma);
      }
    }

    // Clitic stripping fallback:
    // e.g. people've -> people -> person
    final unClitic = LemmatizationEngine.stripClitic(word);
    if (unClitic != null && unClitic.isNotEmpty) {
      add(unClitic);
      final unCliticLemma = TextTokenizer.normalizeLemma(unClitic);
      if (unCliticLemma.isNotEmpty) {
        add(unCliticLemma);
      }
    }

    // Normalized lemma from TextTokenizer
    final lemma = TextTokenizer.normalizeLemma(word);
    if (lemma.isNotEmpty && lemma != word) {
      add(lemma);
    }

    // Plurals: -s, -es, -ies, -ves
    if (word.endsWith('ies') && word.length > 4) {
      add('${word.substring(0, word.length - 3)}y');
    }
    if (word.endsWith('ves') && word.length > 4) {
      final stem = word.substring(0, word.length - 3);
      add('${stem}f');
      add('${stem}fe');
    }
    if (word.endsWith('es') && word.length > 4) {
      add(word.substring(0, word.length - 2));
      if (word.endsWith('les')) {
        add(word.substring(0, word.length - 1)); // noodles -> noodle
      }
    }
    if (word.endsWith('s') && !word.endsWith('ss') && word.length > 3) {
      add(word.substring(0, word.length - 1)); // medications -> medication
    }

    // Past tense and participles: -ed, -ing
    if (word.endsWith('ed') && word.length > 4) {
      final stem = word.substring(0, word.length - 2);
      add('${stem}e'); // created -> create
      add(stem);
      add(word.substring(0, word.length - 1));
    }
    if (word.endsWith('ing') && word.length > 5) {
      final stem = word.substring(0, word.length - 3);
      add('${stem}e');
      add(stem);
    }

    return candidates;
  }

  /// Produces candidate base forms for curated derivational patterns.
  static List<String> _curatedDerivationCandidates(String word) {
    final candidates = <String>[];
    void add(String val) {
      if (val.isNotEmpty && val != word && !candidates.contains(val)) {
        candidates.add(val);
      }
    }

    // -ly adverbs (sourly -> sour, happily -> happy)
    if (word.endsWith('ly') && word.length > 4) {
      final stem = word.substring(0, word.length - 2);
      add(stem);
      if (stem.endsWith('i') && stem.length > 2) {
        add('${stem.substring(0, stem.length - 1)}y');
      }
    }

    // -ness nouns if not found exact (cloudiness -> cloudy)
    if (word.endsWith('ness') && word.length > 5) {
      final stem = word.substring(0, word.length - 4);
      add(stem);
      if (stem.endsWith('i') && stem.length > 2) {
        add('${stem.substring(0, stem.length - 1)}y');
      }
    }

    return candidates;
  }

  /// Evaluates compound words by resolving each component.
  static OfflineLexeme? _matchCompound(String normalized) {
    final components = normalized.split('-');
    final componentLexemes = components
        .map(lookupLexeme)
        .toList(growable: false);

    // If any component is unknown offline, return null for online enrichment
    if (componentLexemes.any((l) => l == null)) return null;

    const rank = {'A1': 0, 'A2': 1, 'B1': 2, 'B2': 3, 'C1': 4, 'C2': 5};
    final graded = componentLexemes
        .whereType<OfflineLexeme>()
        .where((l) => l.cefrLevel != null)
        .toList();

    String? hardestLevel;
    if (graded.isNotEmpty) {
      hardestLevel = graded
          .map((l) => l.cefrLevel!)
          .reduce((hardest, cur) => (rank[cur] ?? 0) > (rank[hardest] ?? 0) ? cur : hardest);
    }

    return OfflineLexeme(
      headword: normalized,
      cefrLevel: hardestLevel,
      isRecognized: true,
      frequencyBand: hardestLevel != null
          ? getFrequencyBand(normalized, hardestLevel)
          : 'Off-list',
      provenance: 'Hyphenated Compound Evaluation',
    );
  }
}
