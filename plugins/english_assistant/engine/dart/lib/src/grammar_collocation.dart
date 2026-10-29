import 'dart:convert';

import 'data/academic_collocations_data.dart';

class GrammarRuleMatch {
  final String ruleId;
  final String text;
  final int start;
  final int end;
  final String name;
  final String description;
  final String note;
  final String color;

  const GrammarRuleMatch({
    required this.ruleId,
    required this.text,
    required this.start,
    required this.end,
    required this.name,
    required this.description,
    required this.note,
    required this.color,
  });

  String get example => text;
  String get category => 'grammar';
}

class CollocationMatch {
  final String text;
  final int start;
  final int end;
  final String category;
  final String type;
  final String explanation;
  final String color;

  const CollocationMatch({
    required this.text,
    required this.start,
    required this.end,
    required this.category,
    required this.type,
    required this.explanation,
    required this.color,
  });
}

class _SurfaceRule {
  final String id;
  final RegExp pattern;
  final String name;
  final String description;
  final String note;
  const _SurfaceRule(
    this.id,
    this.pattern,
    this.name,
    this.description,
    this.note,
  );
}

class GrammarRuleAnalyzer {
  static const unsupportedRules = <String>['PASSIVE_VOICE', 'RELATIVE_CLAUSE'];

  static final _rules = <_SurfaceRule>[
    _SurfaceRule(
      'INVERSION_NEG',
      RegExp(
        r'\b(?:never|seldom|rarely|hardly|scarcely|little)\s+(?:had|has|have|did|does|do|is|are|was|were|can|could|will|would|should|must)\s+(?:not\s+)?[\w’\x27-]+(?:\s+[\w’\x27-]+)?',
        caseSensitive: false,
      ),
      'Negative adverb inversion',
      'Negative adverb followed by auxiliary inversion.',
      'Surface pattern only; no syntactic parse is performed.',
    ),
    _SurfaceRule(
      'INVERSION_NO_SOONER',
      RegExp(
        r'\bno\s+sooner\s+had\s+[\w’\x27-]+(?:\s+[\w’\x27-]+){0,3}\s+than\b',
        caseSensitive: false,
      ),
      'No sooner … than',
      'No sooner followed by had and the than clause.',
      'Surface pattern only; verb forms are not validated.',
    ),
    _SurfaceRule(
      'INVERSION_COND_HAD',
      RegExp(
        r'\bhad\s+[\w’\x27-]+\s+(?:not\s+)?[\w’\x27-]+(?:ed|en|wn|ung|ought|aid)\b',
        caseSensitive: false,
      ),
      'Inverted third conditional',
      'Had + subject + likely participle.',
      'Participle detection is approximate.',
    ),
    _SurfaceRule(
      'INVERSION_COND_WERE',
      RegExp(r'\bwere\s+[\w’\x27-]+\s+(?:to\s+\w+|\w+)', caseSensitive: false),
      'Inverted second conditional',
      'Were + subject + complement or infinitive.',
      'Surface pattern cannot distinguish every use of were.',
    ),
    _SurfaceRule(
      'INVERSION_COND_SHOULD',
      RegExp(r'\bshould\s+[\w’\x27-]+\s+[\w’\x27-]+', caseSensitive: false),
      'Inverted first conditional',
      'Should + subject + base-form candidate.',
      'Surface pattern only; verb form is not validated.',
    ),
    _SurfaceRule(
      'PARTICIPLE_PERFECT',
      RegExp(
        r'\bhaving\s+(?:been\s+)?[\w-]+(?:ed|en|wn|ung|ought|aid)\b',
        caseSensitive: false,
      ),
      'Perfect participle clause',
      'Having + participle, optionally preceded by been.',
      'Participle detection is approximate.',
    ),
    _SurfaceRule(
      'CLEFT_SENTENCE',
      RegExp(
        r'\bit\s+(?:is|was|has\s+been|will\s+be)\s+.{1,80}?\s+(?:that|who|whom|which)\b',
        caseSensitive: false,
      ),
      'Cleft sentence',
      'It + be + focused element + that/who/whom/which.',
      'Surface pattern only; focus clause is not parsed.',
    ),
    _SurfaceRule(
      'USED_TO',
      RegExp(r'\bused\s+to\s+(?![a-z]+ing\b)[a-z]+\b', caseSensitive: false),
      'Past habit (used to)',
      'Subject + used to + base verb candidate.',
      'Does not label be used to + gerund.',
    ),
    _SurfaceRule(
      'PASSIVE_FUTURE',
      RegExp(
        r'\b(?:is|are|am|was|were)\s+going\s+to\s+be\s+[\w-]+(?:ed|en|wn|ung|ought|aid)\b',
        caseSensitive: false,
      ),
      'Future passive',
      'Be going to be + participle candidate.',
      'Participle detection is approximate.',
    ),
    _SurfaceRule(
      'GERUND_AFTER_PREP',
      RegExp(
        r'\b(?:in|of|at|about|by|for|from|without|after|before)\s+[\w-]+ing\b',
        caseSensitive: false,
      ),
      'Gerund after preposition',
      'Preposition followed by an -ing form.',
      'Surface pattern; lexicalized uses may be false positives.',
    ),
  ];

  List<GrammarRuleMatch> analyze(String text) {
    final matches = <GrammarRuleMatch>[];
    for (final rule in _rules) {
      for (final match in rule.pattern.allMatches(text)) {
        final start = text.substring(0, match.start).runes.length;
        matches.add(
          GrammarRuleMatch(
            ruleId: rule.id,
            text: match.group(0)!,
            start: start,
            end: start + match.group(0)!.runes.length,
            name: rule.name,
            description: rule.description,
            note: rule.note,
            color:
                rule.id.startsWith('PASSIVE') || rule.id == 'GERUND_AFTER_PREP'
                ? '#89b4fa'
                : '#3B82F6',
          ),
        );
      }
    }
    matches.sort(
      (a, b) => a.start != b.start
          ? a.start.compareTo(b.start)
          : b.end.compareTo(a.end),
    );
    return matches;
  }
}

class CollocationAnalyzer {
  final List<Map<String, dynamic>> _entries;
  CollocationAnalyzer({List<Map<String, dynamic>>? entries})
    : _entries =
          entries ??
          (jsonDecode(academicCollocationsJson) as List)
              .cast<Map<String, dynamic>>();

  List<CollocationMatch> analyze(String text) {
    final matches = <CollocationMatch>[];
    for (final item in _entries) {
      final phrase = item['phrase'] as String?;
      if (phrase == null || phrase.isEmpty) continue;
      final pattern = RegExp(
        '(?<![A-Za-z])${RegExp.escape(phrase).replaceAll(' ', r'\s+')} (?![A-Za-z])'
            .replaceFirst(' (?!', '(?!'),
        caseSensitive: false,
      );
      for (final match in pattern.allMatches(text)) {
        final surface = match.group(0)!;
        final start = text.substring(0, match.start).runes.length;
        final sourceCategory = item['category'] as String? ?? '';
        final type = sourceCategory.contains('phrasal')
            ? 'Phrasal Verb'
            : sourceCategory.contains('idiom')
            ? 'Idiom'
            : sourceCategory.contains('compound')
            ? 'Compound Word'
            : sourceCategory.contains('grammar')
            ? 'Grammar Expression'
            : 'Academic Collocation';
        final color = type == 'Idiom'
            ? '#8B5CF6'
            : type == 'Compound Word'
            ? '#F59E0B'
            : type == 'Grammar Expression'
            ? '#3B82F6'
            : '#10B981';
        matches.add(
          CollocationMatch(
            text: surface,
            start: start,
            end: start + surface.runes.length,
            category: type == 'Idiom'
                ? 'vocabulary'
                : type == 'Grammar Expression'
                ? 'grammar'
                : 'collocation',
            type: type,
            explanation: item['explanation'] as String? ?? '',
            color: color,
          ),
        );
      }
    }
    matches.sort(
      (a, b) => a.start != b.start
          ? a.start.compareTo(b.start)
          : b.end.compareTo(a.end),
    );
    return matches;
  }
}
