class RawTokenSpan {
  final String surface;
  final int startIndex;
  final int endIndex;

  const RawTokenSpan({
    required this.surface,
    required this.startIndex,
    required this.endIndex,
  });
}

/// Tokenizer that preserves exact character positions and performs robust sentence
/// boundary detection with abbreviation protections.
class TextTokenizer {
  static final Set<String> _abbreviations = {
    'mr', 'mrs', 'ms', 'dr', 'prof', 'sr', 'jr', 'vs', 'etc',
    'eg', 'ie', 'al', 'st', 'ave', 'blvd', 'rd', 'dept', 'univ',
    'jan', 'feb', 'mar', 'apr', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec',
    'u.s', 'u.k', 'e.u', 'ph.d', 'm.d', 'b.a', 'm.a', 'b.s', 'm.s',
    'approx', 'fig', 'no', 'vol', 'pp', 'p',
  };

  /// Splits text into sentences taking care not to split on abbreviations,
  /// initials, or decimal numbers.
  static List<String> extractSentences(String text) {
    if (text.trim().isEmpty) return [];

    final sentences = <String>[];
    final buffer = StringBuffer();
    final length = text.length;

    int i = 0;
    while (i < length) {
      final char = text[i];
      buffer.write(char);

      if (char == '.' || char == '!' || char == '?') {
        // Lookahead to check if this is a genuine sentence boundary
        final isEllipsis = (char == '.' && i + 1 < length && text[i + 1] == '.') ||
            (i > 0 && text[i - 1] == '.');

        // Period directly followed by alphanumeric character without space is mid-token (e.g. U.S., 3.14, example.com)
        final isMidWord = char == '.' &&
            i + 1 < length &&
            RegExp(r'[A-Za-z0-9]').hasMatch(text[i + 1]);

        // Check if preceding token is an abbreviation or initial (e.g., Dr., Mr., U.S., J.)
        final currentText = buffer.toString();
        final lastWordMatch = RegExp(r'([A-Za-z.]+)\s*[.!?]$').firstMatch(currentText);
        final rawWord = lastWordMatch != null ? lastWordMatch.group(1)!.toLowerCase() : '';
        final cleanWord = rawWord.replaceAll('.', '');
        final isAbbrev = _abbreviations.contains(rawWord) ||
            _abbreviations.contains(cleanWord) ||
            cleanWord.length == 1;

        // Check if followed by digit (decimal number like 3.14)
        final isDecimal = char == '.' &&
            i + 1 < length &&
            RegExp(r'\d').hasMatch(text[i + 1]) &&
            i > 0 &&
            RegExp(r'\d').hasMatch(text[i - 1]);

        // Peek next non-space char to see if it's uppercase (start of next sentence)
        var nextCharIdx = i + 1;
        while (nextCharIdx < length && RegExp(r'\s').hasMatch(text[nextCharIdx])) {
          nextCharIdx++;
        }

        final hasNextChar = nextCharIdx < length;
        final nextIsCapital = hasNextChar && RegExp(r'[A-Z0-9"“\-]').hasMatch(text[nextCharIdx]);

        if (!isEllipsis && !isMidWord && !isAbbrev && !isDecimal && (nextIsCapital || !hasNextChar)) {
          final s = buffer.toString().trim();
          if (s.isNotEmpty) {
            sentences.add(s);
          }
          buffer.clear();
        }
      }
      i++;
    }

    final remaining = buffer.toString().trim();
    if (remaining.isNotEmpty) {
      sentences.add(remaining);
    }

    return sentences.isEmpty ? [text.trim()] : sentences;
  }

  /// Extracts individual word tokens along with their exact start and end char indices.
  static List<RawTokenSpan> extractWordSpans(String text) {
    final spans = <RawTokenSpan>[];
    final regex = RegExp(r"\b[A-Za-z0-9]+(?:['’\-][A-Za-z0-9]+)*\b");

    for (final match in regex.allMatches(text)) {
      final surface = match.group(0)!;
      spans.add(RawTokenSpan(
        surface: surface,
        startIndex: match.start,
        endIndex: match.end,
      ));
    }

    return spans;
  }

  /// Determines if a token is a likely proper noun (capitalized in mid-sentence).
  static bool isProperNoun(String word, int wordIndex, bool isSentenceStart) {
    if (word.isEmpty) return false;
    final firstChar = word[0];
    final isCapitalized = firstChar == firstChar.toUpperCase() && RegExp(r'[A-Z]').hasMatch(firstChar);

    if (!isCapitalized) return false;
    if (isSentenceStart) {
      // At sentence start, only classify as proper noun if it remains capitalized in title or known names
      return false;
    }
    return true;
  }

  /// Lemmatize or normalize word by stripping common English inflectional endings
  /// to its base form for lexical lookup.
  static String normalizeLemma(String word) {
    var clean = word.toLowerCase().replaceAll(RegExp(r"[^a-z']"), '');
    if (clean.length <= 3) return clean;

    // Handle possessives
    if (clean.endsWith("'s")) {
      clean = clean.substring(0, clean.length - 2);
    }

    // Irregular verb base mappings
    const irregulars = <String, String>{
      'went': 'go', 'gone': 'go', 'goes': 'go',
      'saw': 'see', 'seen': 'see', 'sees': 'see',
      'ate': 'eat', 'eaten': 'eat', 'eats': 'eat',
      'wrote': 'write', 'written': 'write', 'writes': 'write',
      'took': 'take', 'taken': 'take', 'takes': 'take',
      'made': 'make', 'makes': 'make',
      'gave': 'give', 'given': 'give', 'gives': 'give',
      'knew': 'know', 'known': 'know', 'knows': 'know',
      'thought': 'think', 'thinks': 'think',
      'came': 'come', 'comes': 'come',
      'began': 'begin', 'begun': 'begin', 'begins': 'begin',
      'felt': 'feel', 'feels': 'feel',
      'became': 'become', 'becomes': 'become',
      'left': 'leave', 'leaves': 'leave',
      'brought': 'bring', 'brings': 'bring',
      'taught': 'teach', 'teaches': 'teach',
      'caught': 'catch', 'catches': 'catch',
      'bought': 'buy', 'buys': 'buy',
      'spoke': 'speak', 'spoken': 'speak', 'speaks': 'speak',
      'children': 'child', 'men': 'man', 'women': 'woman',
      'mice': 'mouse', 'feet': 'foot', 'teeth': 'tooth',
      'people': 'person', 'studies': 'study', 'studied': 'study',
    };
    if (irregulars.containsKey(clean)) {
      return irregulars[clean]!;
    }

    // Suffix normalizations
    if (clean.endsWith('ies') && clean.length > 4) {
      return '${clean.substring(0, clean.length - 3)}y';
    }
    if (clean.endsWith('ves') && clean.length > 4) {
      return '${clean.substring(0, clean.length - 3)}f';
    }
    if (clean.endsWith('ing') && clean.length > 5) {
      final stem = clean.substring(0, clean.length - 3);
      if (stem.endsWith('y')) return stem;
      // Double consonant (e.g. running -> run, swimming -> swim)
      if (stem.length >= 3 && stem[stem.length - 1] == stem[stem.length - 2]) {
        return stem.substring(0, stem.length - 1);
      }
      return stem;
    }
    if (clean.endsWith('ed') && clean.length > 4) {
      final stem = clean.substring(0, clean.length - 2);
      if (stem.length >= 3 && stem[stem.length - 1] == stem[stem.length - 2]) {
        return stem.substring(0, stem.length - 1);
      }
      return stem;
    }
    if (clean.endsWith('es') && clean.length > 4) {
      if (RegExp(r'(s|sh|ch|x|z)es$').hasMatch(clean)) {
        return clean.substring(0, clean.length - 2);
      }
    }
    if (clean.endsWith('s') && !clean.endsWith('ss') && clean.length > 3) {
      return clean.substring(0, clean.length - 1);
    }

    return clean;
  }
}
