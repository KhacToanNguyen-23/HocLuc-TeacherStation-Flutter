import '../../domain/models/offline_lexeme.dart';

/// Specialized morphological and lemmatization engine for English tokens.
/// Handles possessives ('s, s', ’s, s’), contractions, clitics, and inflection fallbacks.
class LemmatizationEngine {
  /// Normalizes all Unicode apostrophe variants to standard ASCII apostrophe (').
  static String normalizeApostrophes(String text) {
    if (text.isEmpty) return text;
    return text.replaceAll(RegExp(r"[’ʼ`´]"), "'");
  }

  /// Checks if a token possesses a singular or plural possessive suffix.
  static bool isPossessive(String word) {
    final clean = normalizeApostrophes(word.trim().toLowerCase());
    if (clean.length < 3) return false;
    return clean.endsWith("'s") || clean.endsWith("s'") || clean.endsWith("'");
  }

  /// Strips possessive suffixes ('s, s', or trailing ') from a token.
  /// Returns null if the word does not have a possessive marker.
  ///
  /// Examples:
  /// - "children's" -> "children"
  /// - "students'" -> "students"
  /// - "teacher's" -> "teacher"
  /// - "James'" -> "James"
  static String? stripPossessive(String word) {
    final clean = normalizeApostrophes(word.trim());
    if (clean.length < 3) return null;

    final lower = clean.toLowerCase();
    if (lower.endsWith("'s")) {
      return clean.substring(0, clean.length - 2);
    }
    if (lower.endsWith("s'")) {
      return clean.substring(0, clean.length - 1); // retains 's' for plural base
    }
    if (lower.endsWith("'")) {
      return clean.substring(0, clean.length - 1);
    }
    return null;
  }

  /// Strips auxiliary or modal clitics ('ve, 'll, 're, 'd, 'm, n't) from a token.
  static String? stripClitic(String word) {
    final clean = normalizeApostrophes(word.trim().toLowerCase());
    if (clean.length < 4) return null;

    if (clean.endsWith("n't")) {
      final stem = clean.substring(0, clean.length - 3);
      if (stem == 'wo') return 'will';
      if (stem == 'ca') return 'can';
      if (stem == 'sha') return 'shall';
      return stem;
    }
    if (clean.endsWith("'ve") || clean.endsWith("'ll") || clean.endsWith("'re")) {
      return clean.substring(0, clean.length - 3);
    }
    if (clean.endsWith("'d") || clean.endsWith("'m")) {
      return clean.substring(0, clean.length - 2);
    }
    return null;
  }

  /// Curated dictionary of common English contractions with their base lemma,
  /// standard CEFR level, part-of-speech category, and frequency band.
  static final Map<String, OfflineLexeme> commonContractions = {
    // Negative contractions -> base auxiliary verb (VERB, A1)
    "didn't": const OfflineLexeme(
      headword: 'do',
      cefrLevel: 'A1',
      defaultPos: 'VERB',
      frequencyBand: 'K1',
      provenance: 'Contraction Normalizer',
    ),
    "don't": const OfflineLexeme(
      headword: 'do',
      cefrLevel: 'A1',
      defaultPos: 'VERB',
      frequencyBand: 'K1',
      provenance: 'Contraction Normalizer',
    ),
    "doesn't": const OfflineLexeme(
      headword: 'do',
      cefrLevel: 'A1',
      defaultPos: 'VERB',
      frequencyBand: 'K1',
      provenance: 'Contraction Normalizer',
    ),
    "isn't": const OfflineLexeme(
      headword: 'be',
      cefrLevel: 'A1',
      defaultPos: 'VERB',
      frequencyBand: 'K1',
      provenance: 'Contraction Normalizer',
    ),
    "aren't": const OfflineLexeme(
      headword: 'be',
      cefrLevel: 'A1',
      defaultPos: 'VERB',
      frequencyBand: 'K1',
      provenance: 'Contraction Normalizer',
    ),
    "wasn't": const OfflineLexeme(
      headword: 'be',
      cefrLevel: 'A1',
      defaultPos: 'VERB',
      frequencyBand: 'K1',
      provenance: 'Contraction Normalizer',
    ),
    "weren't": const OfflineLexeme(
      headword: 'be',
      cefrLevel: 'A1',
      defaultPos: 'VERB',
      frequencyBand: 'K1',
      provenance: 'Contraction Normalizer',
    ),
    "haven't": const OfflineLexeme(
      headword: 'have',
      cefrLevel: 'A1',
      defaultPos: 'VERB',
      frequencyBand: 'K1',
      provenance: 'Contraction Normalizer',
    ),
    "hasn't": const OfflineLexeme(
      headword: 'have',
      cefrLevel: 'A1',
      defaultPos: 'VERB',
      frequencyBand: 'K1',
      provenance: 'Contraction Normalizer',
    ),
    "hadn't": const OfflineLexeme(
      headword: 'have',
      cefrLevel: 'A1',
      defaultPos: 'VERB',
      frequencyBand: 'K1',
      provenance: 'Contraction Normalizer',
    ),
    "can't": const OfflineLexeme(
      headword: 'can',
      cefrLevel: 'A1',
      defaultPos: 'VERB',
      frequencyBand: 'K1',
      provenance: 'Contraction Normalizer',
    ),
    "cannot": const OfflineLexeme(
      headword: 'can',
      cefrLevel: 'A1',
      defaultPos: 'VERB',
      frequencyBand: 'K1',
      provenance: 'Contraction Normalizer',
    ),
    "won't": const OfflineLexeme(
      headword: 'will',
      cefrLevel: 'A1',
      defaultPos: 'VERB',
      frequencyBand: 'K1',
      provenance: 'Contraction Normalizer',
    ),
    "wouldn't": const OfflineLexeme(
      headword: 'would',
      cefrLevel: 'A1',
      defaultPos: 'VERB',
      frequencyBand: 'K1',
      provenance: 'Contraction Normalizer',
    ),
    "shouldn't": const OfflineLexeme(
      headword: 'should',
      cefrLevel: 'A1',
      defaultPos: 'VERB',
      frequencyBand: 'K1',
      provenance: 'Contraction Normalizer',
    ),
    "couldn't": const OfflineLexeme(
      headword: 'could',
      cefrLevel: 'A1',
      defaultPos: 'VERB',
      frequencyBand: 'K1',
      provenance: 'Contraction Normalizer',
    ),
    "mustn't": const OfflineLexeme(
      headword: 'must',
      cefrLevel: 'A1',
      defaultPos: 'VERB',
      frequencyBand: 'K1',
      provenance: 'Contraction Normalizer',
    ),
    "needn't": const OfflineLexeme(
      headword: 'need',
      cefrLevel: 'A1',
      defaultPos: 'VERB',
      frequencyBand: 'K1',
      provenance: 'Contraction Normalizer',
    ),

    // Subject Pronoun + Clitic Contractions -> base pronoun (PRON, A1)
    "they're": const OfflineLexeme(
      headword: 'they',
      cefrLevel: 'A1',
      defaultPos: 'PRON',
      frequencyBand: 'K1',
      provenance: 'Contraction Normalizer',
    ),
    "we're": const OfflineLexeme(
      headword: 'we',
      cefrLevel: 'A1',
      defaultPos: 'PRON',
      frequencyBand: 'K1',
      provenance: 'Contraction Normalizer',
    ),
    "you're": const OfflineLexeme(
      headword: 'you',
      cefrLevel: 'A1',
      defaultPos: 'PRON',
      frequencyBand: 'K1',
      provenance: 'Contraction Normalizer',
    ),
    "i'm": const OfflineLexeme(
      headword: 'i',
      cefrLevel: 'A1',
      defaultPos: 'PRON',
      frequencyBand: 'K1',
      provenance: 'Contraction Normalizer',
    ),
    "it's": const OfflineLexeme(
      headword: 'it',
      cefrLevel: 'A1',
      defaultPos: 'PRON',
      frequencyBand: 'K1',
      provenance: 'Contraction Normalizer',
    ),
    "that's": const OfflineLexeme(
      headword: 'that',
      cefrLevel: 'A1',
      defaultPos: 'PRON',
      frequencyBand: 'K1',
      provenance: 'Contraction Normalizer',
    ),
    "what's": const OfflineLexeme(
      headword: 'what',
      cefrLevel: 'A1',
      defaultPos: 'PRON',
      frequencyBand: 'K1',
      provenance: 'Contraction Normalizer',
    ),
    "there's": const OfflineLexeme(
      headword: 'there',
      cefrLevel: 'A1',
      defaultPos: 'ADV',
      frequencyBand: 'K1',
      provenance: 'Contraction Normalizer',
    ),
    "here's": const OfflineLexeme(
      headword: 'here',
      cefrLevel: 'A1',
      defaultPos: 'ADV',
      frequencyBand: 'K1',
      provenance: 'Contraction Normalizer',
    ),
    "who's": const OfflineLexeme(
      headword: 'who',
      cefrLevel: 'A1',
      defaultPos: 'PRON',
      frequencyBand: 'K1',
      provenance: 'Contraction Normalizer',
    ),
    "how's": const OfflineLexeme(
      headword: 'how',
      cefrLevel: 'A1',
      defaultPos: 'ADV',
      frequencyBand: 'K1',
      provenance: 'Contraction Normalizer',
    ),
    "we've": const OfflineLexeme(
      headword: 'we',
      cefrLevel: 'A1',
      defaultPos: 'PRON',
      frequencyBand: 'K1',
      provenance: 'Contraction Normalizer',
    ),
    "they've": const OfflineLexeme(
      headword: 'they',
      cefrLevel: 'A1',
      defaultPos: 'PRON',
      frequencyBand: 'K1',
      provenance: 'Contraction Normalizer',
    ),
    "you've": const OfflineLexeme(
      headword: 'you',
      cefrLevel: 'A1',
      defaultPos: 'PRON',
      frequencyBand: 'K1',
      provenance: 'Contraction Normalizer',
    ),
    "i've": const OfflineLexeme(
      headword: 'i',
      cefrLevel: 'A1',
      defaultPos: 'PRON',
      frequencyBand: 'K1',
      provenance: 'Contraction Normalizer',
    ),
    "they'll": const OfflineLexeme(
      headword: 'they',
      cefrLevel: 'A1',
      defaultPos: 'PRON',
      frequencyBand: 'K1',
      provenance: 'Contraction Normalizer',
    ),
    "we'll": const OfflineLexeme(
      headword: 'we',
      cefrLevel: 'A1',
      defaultPos: 'PRON',
      frequencyBand: 'K1',
      provenance: 'Contraction Normalizer',
    ),
    "you'll": const OfflineLexeme(
      headword: 'you',
      cefrLevel: 'A1',
      defaultPos: 'PRON',
      frequencyBand: 'K1',
      provenance: 'Contraction Normalizer',
    ),
    "i'll": const OfflineLexeme(
      headword: 'i',
      cefrLevel: 'A1',
      defaultPos: 'PRON',
      frequencyBand: 'K1',
      provenance: 'Contraction Normalizer',
    ),
    "he'll": const OfflineLexeme(
      headword: 'he',
      cefrLevel: 'A1',
      defaultPos: 'PRON',
      frequencyBand: 'K1',
      provenance: 'Contraction Normalizer',
    ),
    "she'll": const OfflineLexeme(
      headword: 'she',
      cefrLevel: 'A1',
      defaultPos: 'PRON',
      frequencyBand: 'K1',
      provenance: 'Contraction Normalizer',
    ),
    "it'll": const OfflineLexeme(
      headword: 'it',
      cefrLevel: 'A1',
      defaultPos: 'PRON',
      frequencyBand: 'K1',
      provenance: 'Contraction Normalizer',
    ),
    "they'd": const OfflineLexeme(
      headword: 'they',
      cefrLevel: 'A1',
      defaultPos: 'PRON',
      frequencyBand: 'K1',
      provenance: 'Contraction Normalizer',
    ),
    "we'd": const OfflineLexeme(
      headword: 'we',
      cefrLevel: 'A1',
      defaultPos: 'PRON',
      frequencyBand: 'K1',
      provenance: 'Contraction Normalizer',
    ),
    "you'd": const OfflineLexeme(
      headword: 'you',
      cefrLevel: 'A1',
      defaultPos: 'PRON',
      frequencyBand: 'K1',
      provenance: 'Contraction Normalizer',
    ),
    "i'd": const OfflineLexeme(
      headword: 'i',
      cefrLevel: 'A1',
      defaultPos: 'PRON',
      frequencyBand: 'K1',
      provenance: 'Contraction Normalizer',
    ),
    "he'd": const OfflineLexeme(
      headword: 'he',
      cefrLevel: 'A1',
      defaultPos: 'PRON',
      frequencyBand: 'K1',
      provenance: 'Contraction Normalizer',
    ),
    "she'd": const OfflineLexeme(
      headword: 'she',
      cefrLevel: 'A1',
      defaultPos: 'PRON',
      frequencyBand: 'K1',
      provenance: 'Contraction Normalizer',
    ),
    "let's": const OfflineLexeme(
      headword: 'let',
      cefrLevel: 'A1',
      defaultPos: 'VERB',
      frequencyBand: 'K1',
      provenance: 'Contraction Normalizer',
    ),
  };

  /// Resolves a contraction into its canonical OfflineLexeme representation.
  static OfflineLexeme? resolveContraction(String word) {
    final clean = normalizeApostrophes(word.trim().toLowerCase());
    return commonContractions[clean];
  }
}
