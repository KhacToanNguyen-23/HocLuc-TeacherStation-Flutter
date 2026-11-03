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
/// boundary detection with abbreviation protections and morphological normalization.
class TextTokenizer {
  static final Set<String> _abbreviations = {
    'mr',
    'mrs',
    'ms',
    'dr',
    'prof',
    'sr',
    'jr',
    'vs',
    'etc',
    'eg',
    'ie',
    'al',
    'st',
    'ave',
    'blvd',
    'rd',
    'dept',
    'univ',
    'jan',
    'feb',
    'mar',
    'apr',
    'jun',
    'jul',
    'aug',
    'sep',
    'oct',
    'nov',
    'dec',
    'u.s',
    'u.k',
    'e.u',
    'ph.d',
    'm.d',
    'b.a',
    'm.a',
    'b.s',
    'm.s',
    'approx',
    'fig',
    'no',
    'vol',
    'pp',
    'p',
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
        final isEllipsis =
            (char == '.' && i + 1 < length && text[i + 1] == '.') ||
            (i > 0 && text[i - 1] == '.');

        // Period directly followed by alphanumeric character without space is mid-token (e.g. U.S., 3.14, example.com)
        final isMidWord =
            char == '.' &&
            i + 1 < length &&
            RegExp(r'[A-Za-z0-9]').hasMatch(text[i + 1]);

        // Check if preceding token is an abbreviation or initial (e.g., Dr., Mr., U.S., J.)
        final currentText = buffer.toString();
        final lastWordMatch = RegExp(r'([A-Za-z.]+)\s*[.!?]$')
            .firstMatch(currentText);
        final rawWord = lastWordMatch != null
            ? lastWordMatch.group(1)!.toLowerCase()
            : '';
        final cleanWord = rawWord.replaceAll('.', '');
        final isAbbrev =
            _abbreviations.contains(rawWord) ||
            _abbreviations.contains(cleanWord) ||
            cleanWord.length == 1;

        // Check if followed by digit (decimal number like 3.14)
        final isDecimal =
            char == '.' &&
            i + 1 < length &&
            RegExp(r'\d').hasMatch(text[i + 1]) &&
            i > 0 &&
            RegExp(r'\d').hasMatch(text[i - 1]);

        // Peek next non-space char to see if it's uppercase (start of next sentence)
        var nextCharIdx = i + 1;
        while (nextCharIdx < length &&
            RegExp(r'\s').hasMatch(text[nextCharIdx])) {
          nextCharIdx++;
        }

        final hasNextChar = nextCharIdx < length;
        final nextIsCapital =
            hasNextChar && RegExp(r'[A-Z0-9"“\-]').hasMatch(text[nextCharIdx]);

        if (!isEllipsis &&
            !isMidWord &&
            !isAbbrev &&
            !isDecimal &&
            (nextIsCapital || !hasNextChar)) {
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
    final regex = RegExp(
      r"\b[A-Za-z0-9]+(?:['’\-‐‑‒–—―−][A-Za-z0-9]+)*(?:(?<=[sS])['’](?=[^A-Za-z0-9]|$))?",
    );

    for (final match in regex.allMatches(text)) {
      var surface = match.group(0)!;
      var start = match.start;
      var end = match.end;

      // If wrapped in single quotes like 'hello', strip trailing closing quote
      if (start > 0 &&
          (text[start - 1] == "'" || text[start - 1] == '’') &&
          (surface.endsWith("'") || surface.endsWith('’'))) {
        surface = surface.substring(0, surface.length - 1);
        end = end - 1;
      }

      spans.add(
        RawTokenSpan(surface: surface, startIndex: start, endIndex: end),
      );
    }

    return spans;
  }

  /// Keeps a compound as one normalized lookup key for the online dictionary.
  static String normalizeCompoundLemma(String word) => word
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r"[’ʼ`´]"), "'")
      .replaceAll(RegExp(r'[‐‑‒–—―−]'), '-')
      .replaceAll(RegExp(r"[^a-z0-9'-]"), '');

  /// Normalizes ordinary words while preserving hyphenated compounds intact.
  static String normalizeTokenLemma(String word) {
    final normalized = normalizeCompoundLemma(word);
    if (normalized.contains('-')) return normalized;
    final lemma = normalizeLemma(normalized);
    return _isUnsafeDerivationalRewrite(normalized, lemma) ? normalized : lemma;
  }

  /// Candidate dictionary forms for an offline lookup. Exact forms are first;
  /// only inflectional rewrites may follow. Derivational lemmas can still be
  /// useful for display/API lookup, but must not transfer a CEFR label across
  /// parts of speech without an explicit mapping.
  static List<String> lookupCandidates(String word) {
    final normalizedSurface = word.toLowerCase();
    if (RegExp(r"[\-‐‑‒–—―−]").hasMatch(normalizedSurface)) {
      return const [];
    }
    final clean = word.toLowerCase().replaceAll(RegExp(r"[^a-z']"), '');
    if (clean.isEmpty) return const [];
    if (_invariantPluralForms.contains(clean)) return [clean];

    final candidates = <String>[];
    final seen = <String>{};
    final pending = <(String, int)>[(clean, 0)];
    for (var index = 0; index < pending.length; index++) {
      final (current, depth) = pending[index];
      if (seen.add(current)) candidates.add(current);
      if (depth >= 2) continue;

      final normalized = normalizeLemma(current);
      if (normalized.isNotEmpty &&
          !_isUnsafeDerivationalRewrite(current, normalized) &&
          seen.add(normalized)) {
        candidates.add(normalized);
        pending.add((normalized, depth + 1));
      }
      for (final stem in _suffixCandidates(current)) {
        if (stem.isEmpty || stem.length < 3 || !seen.add(stem)) continue;
        candidates.add(stem);
        pending.add((stem, depth + 1));
      }
    }
    return candidates;
  }

  static List<String> _suffixCandidates(String word) {
    final stems = <String>[];
    void add(String value) {
      if (value.isNotEmpty && !stems.contains(value)) stems.add(value);
    }

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
    }
    if (word.endsWith('s') && !word.endsWith('ss') && word.length > 3) {
      add(word.substring(0, word.length - 1));
    }
    if (word.endsWith('ing') && word.length > 5) {
      var stem = word.substring(0, word.length - 3);
      add(stem);
      if (_isDoubledFinalConsonant(stem)) {
        stem = stem.substring(0, stem.length - 1);
        add(stem);
      }
      add('${stem}e');
    }
    if (word.endsWith('ed') && word.length > 4) {
      var stem = word.substring(0, word.length - 2);
      add(stem);
      if (_isDoubledFinalConsonant(stem)) {
        stem = stem.substring(0, stem.length - 1);
        add(stem);
      }
      add('${stem}e');
    }
    return stems;
  }

  static bool _isUnsafeDerivationalRewrite(String word, String normalized) {
    if (word == normalized) return false;
    if (const {'better', 'best', 'further', 'furthest'}.contains(word)) {
      return false;
    }
    if (const [
      'ation',
      'ness',
      'ly',
      'er',
      'est',
      'ment',
      'able',
      'ible',
      'less',
      'ful',
      'ish',
      'ity',
    ].any(word.endsWith)) {
      return true;
    }
    return false;
  }

  static const _invariantPluralForms = {
    'species',
    'series',
    'news',
    'mathematics',
    'physics',
    'politics',
    'economics',
  };

  static const _baseWordsEndingInEr = <String>{
    'bitter',
    'water',
    'paper',
    'letter',
    'matter',
    'butter',
    'dinner',
    'summer',
    'hammer',
    'banner',
    'manner',
    'ladder',
    'rubber',
    'copper',
    'timber',
    'member',
    'number',
    'finger',
    'winter',
    'silver',
    'order',
    'other',
    'after',
    'under',
    'over',
    'never',
    'lever',
    'clever',
    'river',
    'cover',
    'discover',
    'proper',
    'corner',
    'danger',
    'anger',
    'hunger',
    'linger',
    'singer',
    'ginger',
    'gather',
    'father',
    'mother',
    'brother',
    'sister',
    'weather',
    'feather',
    'leather',
    'together',
    'another',
    'bother',
  };

  static bool _isDoubledFinalConsonant(String word) =>
      word.length > 3 &&
      word.codeUnitAt(word.length - 1) == word.codeUnitAt(word.length - 2) &&
      RegExp(r'[b-df-hj-np-tv-z]').hasMatch(word[word.length - 1]);

  /// Determines if a token is a likely proper noun (capitalized in mid-sentence).
  static bool isProperNoun(String word, int wordIndex, bool isSentenceStart) {
    if (word.isEmpty) return false;
    final firstChar = word[0];
    final isCapitalized =
        firstChar == firstChar.toUpperCase() &&
        RegExp(r'[A-Z]').hasMatch(firstChar);

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
    var clean = word
        .toLowerCase()
        .replaceAll(RegExp(r"[’ʼ`´]"), "'")
        .replaceAll(RegExp(r"[^a-z']"), '');
    if (clean.isEmpty) return clean;

    // Handle possessives ('s, trailing s', or trailing ')
    if (clean.endsWith("'s")) {
      clean = clean.substring(0, clean.length - 2);
    } else if (clean.endsWith("s'")) {
      clean = clean.substring(0, clean.length - 1);
    } else if (clean.endsWith("'")) {
      clean = clean.substring(0, clean.length - 1);
    }
    if (_invariantPluralForms.contains(clean)) return clean;

    // Irregular verb and adjective base mappings
    const irregulars = <String, String>{
      'went': 'go',
      'gone': 'go',
      'goes': 'go',
      'saw': 'see',
      'seen': 'see',
      'sees': 'see',
      'ate': 'eat',
      'eaten': 'eat',
      'eats': 'eat',
      'drank': 'drink',
      'drunk': 'drink',
      'drinking': 'drink',
      'drinks': 'drink',
      'were': 'be',
      'was': 'be',
      'been': 'be',
      'being': 'be',
      'am': 'be',
      'is': 'be',
      'are': 'be',
      'wrote': 'write',
      'written': 'write',
      'writes': 'write',
      'took': 'take',
      'taken': 'take',
      'takes': 'take',
      'made': 'make',
      'makes': 'make',
      'gave': 'give',
      'given': 'give',
      'gives': 'give',
      'knew': 'know',
      'known': 'know',
      'knows': 'know',
      'thought': 'think',
      'thinks': 'think',
      'found': 'find',
      'finding': 'find',
      'finds': 'find',
      'came': 'come',
      'comes': 'come',
      'began': 'begin',
      'begun': 'begin',
      'begins': 'begin',
      'felt': 'feel',
      'feels': 'feel',
      'became': 'become',
      'becomes': 'become',
      'left': 'leave',
      'leaves': 'leave',
      'brought': 'bring',
      'brings': 'bring',
      'taught': 'teach',
      'teaches': 'teach',
      'caught': 'catch',
      'catches': 'catch',
      'bought': 'buy',
      'buys': 'buy',
      'spoke': 'speak',
      'spoken': 'speak',
      'speaks': 'speak',
      'had': 'have',
      'has': 'have',
      'having': 'have',
      'did': 'do',
      'done': 'do',
      'doing': 'do',
      'does': 'do',
      'said': 'say',
      'saying': 'say',
      'says': 'say',
      'got': 'get',
      'gotten': 'get',
      'getting': 'get',
      'gets': 'get',
      'held': 'hold',
      'holding': 'hold',
      'holds': 'hold',
      'stood': 'stand',
      'standing': 'stand',
      'stands': 'stand',
      'sat': 'sit',
      'sitting': 'sit',
      'sits': 'sit',
      'lost': 'lose',
      'losing': 'lose',
      'loses': 'lose',
      'paid': 'pay',
      'paying': 'pay',
      'pays': 'pay',
      'met': 'meet',
      'meeting': 'meet',
      'meets': 'meet',
      'sent': 'send',
      'sending': 'send',
      'sends': 'send',
      'built': 'build',
      'building': 'build',
      'builds': 'build',
      'drawn': 'draw',
      'drew': 'draw',
      'drawing': 'draw',
      'draws': 'draw',
      'broken': 'break',
      'broke': 'break',
      'breaking': 'break',
      'breaks': 'break',
      'spent': 'spend',
      'spending': 'spend',
      'spends': 'spend',
      'grown': 'grow',
      'grew': 'grow',
      'growing': 'grow',
      'grows': 'grow',
      'led': 'lead',
      'leading': 'lead',
      'leads': 'lead',
      'chosen': 'choose',
      'chose': 'choose',
      'choosing': 'choose',
      'chooses': 'choose',
      'driven': 'drive',
      'drove': 'drive',
      'driving': 'drive',
      'drives': 'drive',
      'fallen': 'fall',
      'fell': 'fall',
      'falling': 'fall',
      'falls': 'fall',
      'flown': 'fly',
      'flew': 'fly',
      'flying': 'fly',
      'flies': 'fly',
      'ran': 'run',
      'runs': 'run',
      'swum': 'swim',
      'swam': 'swim',
      'swims': 'swim',
      'sung': 'sing',
      'sang': 'sing',
      'sings': 'sing',
      'hidden': 'hide',
      'hid': 'hide',
      'hides': 'hide',
      'frozen': 'freeze',
      'froze': 'freeze',
      'freezes': 'freeze',
      'bitten': 'bite',
      'bit': 'bite',
      'biting': 'bite',
      'bites': 'bite',
      'shown': 'show',
      'showed': 'show',
      'showing': 'show',
      'shows': 'show',
      'worn': 'wear',
      'wore': 'wear',
      'wearing': 'wear',
      'wears': 'wear',
      'blown': 'blow',
      'blew': 'blow',
      'blowing': 'blow',
      'blows': 'blow',
      'better': 'good',
      'best': 'good',
      'worse': 'bad',
      'worst': 'bad',
      'less': 'little',
      'least': 'little',
      'more': 'much',
      'most': 'much',
      'further': 'far',
      'furthest': 'far',
      'children': 'child',
      'analyses': 'analysis',
      'crises': 'crisis',
      'diagnoses': 'diagnosis',
      'hypotheses': 'hypothesis',
      'men': 'man',
      'women': 'woman',
      'mice': 'mouse',
      'feet': 'foot',
      'teeth': 'tooth',
      'people': 'person',
      'parentheses': 'parenthesis',
      'synopses': 'synopsis',
      'theses': 'thesis',
      'studies': 'study',
      'studied': 'study',
    };
    if (irregulars.containsKey(clean)) {
      return irregulars[clean]!;
    }

    if (clean.length <= 3) return clean;

    // Suffix normalizations
    if (clean.endsWith('ies') && clean.length > 4) {
      return '${clean.substring(0, clean.length - 3)}y';
    }
    if (clean.endsWith('ves') && clean.length > 4) {
      return '${clean.substring(0, clean.length - 3)}f';
    }
    if (clean.endsWith('ness') && clean.length > 5) {
      final stem = clean.substring(0, clean.length - 4);
      if (stem.endsWith('i') && stem.length > 2) {
        return '${stem.substring(0, stem.length - 1)}y';
      }
      return stem;
    }
    if (clean.endsWith('ing') && clean.length > 5) {
      if (RegExp(r'(at|ut|id|ud|uc|os|as|is|iz|iv|ov|ir|ur|lv|ng|ag)ing$')
          .hasMatch(clean)) {
        return '${clean.substring(0, clean.length - 3)}e';
      }
      final stem = clean.substring(0, clean.length - 3);
      if (stem.endsWith('y')) return stem;
      if (stem.endsWith('ll')) return stem;
      if (stem.length >= 3 &&
          stem[stem.length - 1] == stem[stem.length - 2] &&
          'bdgmnpt'.contains(stem[stem.length - 1])) {
        return stem.substring(0, stem.length - 1);
      }
      return stem;
    }
    if (clean.endsWith('est') && clean.length > 5) {
      final stem = clean.substring(0, clean.length - 3);
      if (stem.endsWith('ll')) return stem;
      if (stem.length >= 3 &&
          stem[stem.length - 1] == stem[stem.length - 2] &&
          'bdgmnpt'.contains(stem[stem.length - 1])) {
        return stem.substring(0, stem.length - 1);
      }
      return stem;
    }
    if (clean.endsWith('er') &&
        clean.length > 4 &&
        !_baseWordsEndingInEr.contains(clean)) {
      final stem = clean.substring(0, clean.length - 2);
      if (stem.endsWith('ll')) return stem;
      if (stem.length >= 3 &&
          stem[stem.length - 1] == stem[stem.length - 2] &&
          'bdgmnpt'.contains(stem[stem.length - 1])) {
        return stem.substring(0, stem.length - 1);
      }
      return stem;
    }
    if (clean.endsWith('ed') && clean.length > 4) {
      if (RegExp(r'(at|ut|id|ud|uc|os|as|is|iz|iv|ov|ir|ur|lv|ng|ag)ed$')
          .hasMatch(clean)) {
        return clean.substring(0, clean.length - 1);
      }
      final stem = clean.substring(0, clean.length - 2);
      if (stem.endsWith('ll')) return stem;
      if (stem.length >= 3 &&
          stem[stem.length - 1] == stem[stem.length - 2] &&
          'bdgmnpt'.contains(stem[stem.length - 1])) {
        return stem.substring(0, stem.length - 1);
      }
      return stem;
    }
    if (clean.endsWith('es') && clean.length > 4) {
      if (RegExp(r'(s|sh|ch|x|z)es$').hasMatch(clean)) {
        return clean.substring(0, clean.length - 2);
      }
      if (clean.endsWith('les')) {
        return clean.substring(0, clean.length - 1);
      }
    }
    if (clean.endsWith('s') && !clean.endsWith('ss') && clean.length > 3) {
      return clean.substring(0, clean.length - 1);
    }

    return clean;
  }
}
