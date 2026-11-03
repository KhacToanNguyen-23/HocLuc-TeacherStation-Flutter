/// Deterministic syllable counter for English words.
/// Implements standard English phonological heuristics (vowel grouping, silent 'e',
/// diphthongs, special suffixes) widely adopted in readability formulas.
class SyllableCounter {
  static final RegExp _vowelRegex = RegExp(r'[aeiouy]+', caseSensitive: false);

  /// Count syllables in a single word.
  static int countSyllables(String word) {
    final clean = word.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    if (clean.isEmpty) return 0;
    if (clean.length <= 3) return 1;

    // Direct overrides for known irregular words
    const exceptions = <String, int>{
      'the': 1,
      'there': 1,
      'here': 1,
      'where': 1,
      'some': 1,
      'come': 1,
      'done': 1,
      'gone': 1,
      'one': 1,
      'two': 1,
      'are': 1,
      'were': 1,
      'have': 1,
      'give': 1,
      'live': 1,
      'love': 1,
      'move': 1,
      'prove': 1,
      'people': 2,
      'simple': 2,
      'little': 2,
      'table': 2,
      'able': 2,
      'business': 2,
      'chocolate': 2,
      'different': 2,
      'interesting': 3,
      'area': 3,
      'idea': 3,
      'video': 3,
      'radio': 2,
      'create': 2,
    };
    if (exceptions.containsKey(clean)) {
      return exceptions[clean]!;
    }

    var temp = clean;

    // Discard trailing silent 'e', but keep '-le' preceded by consonant (e.g. 'ta-ble', 'sim-ple')
    if (temp.endsWith('e') && !temp.endsWith('le')) {
      temp = temp.substring(0, temp.length - 1);
    } else if (temp.endsWith('ed')) {
      // '-ed' is only an extra syllable if preceded by 't' or 'd' (e.g., wanted, needed)
      if (!temp.endsWith('ted') && !temp.endsWith('ded')) {
        temp = temp.substring(0, temp.length - 2);
      }
    } else if (temp.endsWith('es')) {
      // '-es' is only an extra syllable if preceded by s, z, x, ch, sh, c, g
      if (!RegExp(r'(s|z|x|ch|sh|c|g)es$').hasMatch(temp)) {
        temp = temp.substring(0, temp.length - 2);
      }
    }

    // Match all continuous vowel clusters
    final matches = _vowelRegex.allMatches(temp);
    var count = matches.length;

    // Adjust for consonant + 'le' (e.g., bot-tle, a-ble)
    if (RegExp(r'[^aeiouy]le$').hasMatch(clean)) {
      count++;
    }

    // Adjust for common suffixes that create extra syllables
    if (clean.endsWith('tion') || clean.endsWith('sion')) {
      // usually one syllable for the suffix itself
    } else if (clean.endsWith('ia') ||
        clean.endsWith('io') ||
        clean.endsWith('ious')) {
      count++;
    }

    return count < 1 ? 1 : count;
  }

  /// Whether a word is polysyllabic (>= 3 syllables).
  static bool isPolysyllabic(String word) {
    return countSyllables(word) >= 3;
  }

  /// Whether a word is a "complex word" under Gunning Fog criteria:
  /// 3 or more syllables, excluding proper nouns, compound words of simple words,
  /// and words made 3 syllables by standard inflectional suffixes (-es, -ed, -ing).
  static bool isComplexWord(String word, {bool isProperNoun = false}) {
    if (isProperNoun) return false;
    final clean = word.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    if (clean.length < 5) return false;

    final rawSyllables = countSyllables(clean);
    if (rawSyllables < 3) return false;

    // Check if adding -ed, -es, or -ing pushed a 2-syllable word into 3 syllables
    if (clean.endsWith('ing') && clean.length > 5) {
      final base = clean.substring(0, clean.length - 3);
      if (countSyllables(base) < 3) return false;
    }
    if (clean.endsWith('ed') && clean.length > 4) {
      final base = clean.substring(0, clean.length - 2);
      if (countSyllables(base) < 3) return false;
    }
    if (clean.endsWith('es') && clean.length > 4) {
      final base = clean.substring(0, clean.length - 2);
      if (countSyllables(base) < 3) return false;
    }

    return true;
  }
}
