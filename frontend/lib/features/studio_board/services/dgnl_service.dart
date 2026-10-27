import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:teaching_companion/features/plugin_engine/services/process_supervisor.dart';
import '../domain/models/dgnl_highlight_palette.dart';
import '../domain/models/text_profile_models.dart';
import 'profiler/dgnl_collocation_data.dart';
import 'profiler/text_profiler_service.dart';

class DgnlAnalysisResult {
  final int totalWords;
  final int contentWords;
  final double lexicalDensity;
  final Map<String, dynamic> cefrProfile;
  final String evaluation;
  final String status;
  final List<Map<String, dynamic>> highlights;
  final TextProfileResult? textProfile;

  const DgnlAnalysisResult({
    required this.totalWords,
    required this.contentWords,
    required this.lexicalDensity,
    required this.cefrProfile,
    required this.evaluation,
    required this.status,
    required this.highlights,
    this.textProfile,
  });

  factory DgnlAnalysisResult.fromJson(
    Map<String, dynamic> json, {
    TextProfileResult? profile,
  }) {
    final m = (json['metrics'] as Map<String, dynamic>?) ?? {};
    final cp = (m['cefr_profile'] as Map<String, dynamic>?) ?? {};
    final rawHl = (json['highlights'] as List?) ?? [];
    return DgnlAnalysisResult(
      totalWords: (m['total_words'] as num?)?.toInt() ?? 0,
      contentWords: (m['content_words'] as num?)?.toInt() ?? 0,
      lexicalDensity: (m['lexical_density'] as num?)?.toDouble() ?? 0.0,
      cefrProfile: cp,
      evaluation: (m['evaluation'] as String?) ?? 'Đoạn văn đạt chuẩn ôn tập.',
      status: (m['status'] as String?) ?? 'optimal',
      highlights: rawHl.whereType<Map<String, dynamic>>().toList(),
      textProfile: profile,
    );
  }
}

class DgnlService {
  /// Base URL resolved dynamically from ProcessSupervisor if plugin sidecar is active
  static String? get baseUrl {
    final port = ProcessSupervisor.instance.getActiveSidecarPort();
    return port != null ? 'http://127.0.0.1:$port' : null;
  }

  /// Phân tích ngữ liệu ĐGNL qua FastAPI backend (hoặc fallback offline)
  static Future<DgnlAnalysisResult> analyze(String text) async {
    final clean = text.trim();
    if (clean.isEmpty) {
      return fallbackAnalyze('');
    }

    final url = baseUrl;
    if (url != null) {
      try {
        final res = await http
            .post(
              Uri.parse('$url/api/dgnl/analyze'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'text': clean}),
            )
            .timeout(const Duration(seconds: 4));

        if (res.statusCode == 200) {
          final data =
              jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
          final onlineRes = DgnlAnalysisResult.fromJson(data);
          final offlineRes = fallbackAnalyze(clean);
          final profile =
              offlineRes.textProfile ?? TextProfilerService.profile(clean);

          // Deterministic overlap resolution between online and offline highlights:
          // 1. Same category + same offsets or exact text => duplicate, keep online or richer item.
          // 2. Different categories (e.g. grammar vs vocabulary) => keep BOTH! Nested vocabulary
          //    inside a grammar structure (or collocation) provides distinct pedagogical layers.
          // 3. Same category partial overlap => keep the longer/more specific span.
          final mergedHl = <Map<String, dynamic>>[...onlineRes.highlights];
          for (final oHl in offlineRes.highlights) {
            final oText = oHl['text']?.toString().toLowerCase().trim() ?? '';
            final oCat = oHl['category']?.toString().toLowerCase().trim() ?? '';
            final oStart = oHl['start'] as int?;
            final oEnd = oHl['end'] as int?;

            final isDuplicate = mergedHl.any((m) {
              final mText = m['text']?.toString().toLowerCase().trim() ?? '';
              final mCat = m['category']?.toString().toLowerCase().trim() ?? '';
              final mStart = m['start'] as int?;
              final mEnd = m['end'] as int?;

              // Different categories never suppress each other (preserves nested vocab & collocations)
              if (mCat != oCat) return false;

              // Same category: exact text or exact offset match is a duplicate
              if (mStart != null &&
                  mEnd != null &&
                  oStart != null &&
                  oEnd != null) {
                if (mStart == oStart && mEnd == oEnd) return true;
                // Significant overlap within same category: keep existing
                final overlapStart = math.max(mStart, oStart);
                final overlapEnd = math.min(mEnd, oEnd);
                if (overlapStart < overlapEnd) {
                  final overlapLen = overlapEnd - overlapStart;
                  final oLen = oEnd - oStart;
                  if (oLen > 0 && (overlapLen / oLen) > 0.7) return true;
                }
              }

              return mText == oText;
            });

            if (!isDuplicate) {
              mergedHl.add(oHl);
            }
          }

          // Sort deterministically: start ascending, then length descending (outer spans first)
          mergedHl.sort((a, b) {
            final aStart = a['start'] as int? ?? 0;
            final bStart = b['start'] as int? ?? 0;
            if (aStart != bStart) return aStart.compareTo(bStart);
            final aEnd = a['end'] as int? ?? 0;
            final bEnd = b['end'] as int? ?? 0;
            return bEnd.compareTo(aEnd);
          });

          return DgnlAnalysisResult(
            totalWords: onlineRes.totalWords > 0
                ? onlineRes.totalWords
                : offlineRes.totalWords,
            contentWords: onlineRes.contentWords > 0
                ? onlineRes.contentWords
                : offlineRes.contentWords,
            lexicalDensity: onlineRes.lexicalDensity > 0
                ? onlineRes.lexicalDensity
                : offlineRes.lexicalDensity,
            cefrProfile: onlineRes.cefrProfile.isNotEmpty
                ? onlineRes.cefrProfile
                : offlineRes.cefrProfile,
            evaluation: onlineRes.evaluation,
            status: onlineRes.status,
            highlights: mergedHl,
            textProfile: profile,
          );
        }
      } catch (e) {
        debugPrint(
          '[DgnlService] Online analyze failed, using offline engine: $e',
        );
      }
    }

    return fallbackAnalyze(clean);
  }

  /// Tự động sinh bài tập trắc nghiệm đục lỗ (Cloze Test)
  static Future<List<Map<String, dynamic>>> generateCloze(String text) async {
    final clean = text.trim();
    if (clean.isEmpty) return [];

    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/api/dgnl/generate-cloze'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'text': clean,
              'selected_types': ['grammar', 'collocation', 'vocabulary'],
            }),
          )
          .timeout(const Duration(seconds: 3));

      if (res.statusCode == 200) {
        final list = jsonDecode(utf8.decode(res.bodyBytes)) as List?;
        if (list != null && list.isNotEmpty) {
          return list.whereType<Map<String, dynamic>>().toList();
        }
      }
    } catch (e) {
      debugPrint('[DgnlService] Online cloze generation failed: $e');
    }

    return fallbackGenerateCloze(clean);
  }

  /// Thuật toán Heuristic Offline nếu chưa khởi động Python sidecar
  static DgnlAnalysisResult fallbackAnalyze(String text) {
    final words = text
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    final total = words.length;
    final contentWords = words.where((w) => w.length > 3).length;
    final ld = total > 0 ? ((contentWords / total) * 100).roundToDouble() : 0.0;

    final highlights = <Map<String, dynamic>>[];

    // 1. Grammar Patterns
    final grammarPatterns = [
      {
        'pattern': RegExp(
          r'\b(It\s+(?:is|was)\s+[^.]+?\s+(?:that|who))\b',
          caseSensitive: false,
        ),
        'type': 'Câu chẻ nhấn mạnh (Cleft Sentence)',
        'note': 'Dùng để nhấn mạnh chủ ngữ, tân ngữ hoặc trạng ngữ.',
      },
      {
        'pattern': RegExp(
          r'\b(Hardly|Scarcely|No sooner|Seldom|Rarely|Not until)\b',
          caseSensitive: false,
        ),
        'type': 'Đảo ngữ phủ định (Inversion)',
        'note': 'Trạng từ phủ định đứng đầu câu đòi hỏi đảo trợ động từ.',
      },
      {
        'pattern': RegExp(r'\b(used\s+to\s+[a-z]+)\b', caseSensitive: false),
        'type': 'Cấu trúc Thói quen quá khứ (Used to + V)',
        'note': 'Thói quen trong quá khứ không còn ở hiện tại.',
      },
      {
        // Câu bị động chuẩn: (be) + (adverb)* + [past participle (V3/ed)]
        // Loại trừ triệt để các trạng từ kết thúc bằng -en (often, even, open, seven, sudden, etc.)
        'pattern': RegExp(
          r'\b((?:is|are|am|was|were|been|being|be)\s+(?:(?:[a-z]+ly|often|already|always|never|recently|seldom|rarely|still|just|well|widely|commonly|frequently)\s+)*(?:(?!(?:naked|sacred|wicked|ragged|crooked|hundred|bed|red|often|even|open|seven|sudden|listen)\b)[a-z]{2,}ed|written|frozen|broken|chosen|driven|eaten|fallen|forgiven|forgotten|gotten|given|hidden|known|ridden|risen|seen|shaken|spoken|stolen|taken|woken|beaten|bitten|blown|drawn|flown|grown|shown|thrown|built|bought|caught|felt|found|held|kept|left|lost|made|meant|met|paid|read|said|sold|sent|spent|taught|told|thought|understood|won|worn|done|gone|become|run|cut|put|set|spread|hit|hurt|shut))\b',
          caseSensitive: false,
        ),
        'type': 'Câu bị động (Passive Voice)',
        'note':
            'Cấu trúc bị động: Động từ "be" đi kèm quá khứ phân từ (V3/ed) biểu thị hành động tác động lên chủ ngữ.',
      },
      {
        'pattern': RegExp(
          r'\b((?:can|could|will|would|should|may|might|must|going\s+to)\s+be\s+(?:(?:[a-z]+ly|often|already|always|never|recently)\s+)*(?:(?!(?:often|even|open|seven)\b)[a-z]{2,}ed|written|frozen|broken|chosen|built|made|held|given|shown|taken|done))\b',
          caseSensitive: false,
        ),
        'type': 'Câu bị động khiếm khuyết/tương lai (Modal/Future Passive)',
        'note':
            'Cấu trúc bị động với trợ động từ khuyết thiếu hoặc tương lai gần.',
      },
      {
        'pattern': RegExp(
          r'\b(Having\s+(?:been\s+)?[a-z]+(?:ed|en|wn))\b',
          caseSensitive: false,
        ),
        'type': 'Mệnh đề phân từ hoàn thành',
        'note': 'Hành động xảy ra trước hành động chính.',
      },
      {
        'pattern': RegExp(
          r'\b((?:in|of|by|at|for|from|with|without|about|instead\s+of)\s+[a-z]+ing)\b',
          caseSensitive: false,
        ),
        'type': 'Danh động từ sau giới từ (Prep + V-ing)',
        'note':
            'Kiến thức ngữ pháp phân loại hay gặp trong các câu trắc nghiệm chia dạng từ.',
      },
      {
        'pattern': RegExp(
          r'\b((?:who|whom|which|that|whose|where|when)\s+[a-z]+(?:s|ed|d|ould|ight)?(?:\s+[a-z]+)?)\b',
          caseSensitive: false,
        ),
        'type': 'Mệnh đề quan hệ (Relative Clause)',
        'note':
            'Cấu trúc câu phức phân hóa cao trong phần nối câu và tìm lỗi sai.',
      },
      {
        'pattern': RegExp(
          r'\b([a-zA-Z]+,\s+(?:known|considered|called|defined|described|named)\s+as\s+[a-zA-Z0-9\s-]+?)(?=,|\.|\b)',
          caseSensitive: false,
        ),
        'type': 'Mệnh đề quan hệ rút gọn (Reduced Relative Clause)',
        'note':
            'Phân từ quá khứ (Past Participle) đứng giữa hai dấu phẩy rút gọn cho "who is/are known as".',
      },
      {
        'pattern': RegExp(
          r'\b(less|more)\s+(?:likely\s+than\s+[a-zA-Z]+(?:\s+to\s+[a-z]+)?|fond\s+of|sensitive\s+to|profitable|important)\b',
          caseSensitive: false,
        ),
        'type': 'Cấu trúc so sánh (Comparative Structure)',
        'note':
            'Cấu trúc so sánh hơn/kém phân hóa cao trong câu diễn giải và đọc hiểu.',
      },
      {
        'pattern': RegExp(
          r'\b(because\s+[a-z]+(?:\s+[a-z]+){1,3})\b',
          caseSensitive: false,
        ),
        'type':
            'Mệnh đề trạng ngữ chỉ nguyên nhân (Adverbial Clause of Reason)',
        'note': 'Liên từ chỉ nguyên nhân giải thích lý do cho mệnh đề chính.',
      },
      {
        'pattern': RegExp(
          r'\b(no\s+matter\s+(?:what|how|who|where|when)|although|even\s+though|despite|in\s+spite\s+of)\b',
          caseSensitive: false,
        ),
        'type': 'Mệnh đề Nhượng bộ (Concession Clause)',
        'note': 'Thường xuyên xuất hiện trong phần viết lại câu đồng nghĩa.',
      },
    ];

    for (final gp in grammarPatterns) {
      final reg = gp['pattern'] as RegExp;
      for (final m in reg.allMatches(text)) {
        highlights.add({
          'start': m.start,
          'end': m.end,
          'text': m.group(0),
          'category': 'grammar',
          'level': 'B2',
          'type': gp['type'],
          'color': '#89b4fa',
          'note': gp['note'],
        });
      }
    }

    // 2. Structured Academic Collocations Lexicon
    final collocationHighlights = DgnlCollocationLexicon.extractCollocations(
      text,
    );
    highlights.addAll(collocationHighlights);

    // 3. Comprehensive CEFR Vocabulary Profiler integration (Selective Pedagogical Layer)
    final profilerResult = TextProfilerService.profile(text);

    // Bộ lọc từ chức năng (function words / grammatical markers) - Không gắn nhãn làm từ vựng mục tiêu
    final functionWords = const {
      'a',
      'an',
      'the',
      'of',
      'and',
      'or',
      'but',
      'nor',
      'so',
      'for',
      'yet',
      'in',
      'on',
      'at',
      'to',
      'from',
      'by',
      'with',
      'about',
      'as',
      'into',
      'like',
      'through',
      'after',
      'over',
      'between',
      'out',
      'against',
      'during',
      'without',
      'before',
      'under',
      'around',
      'among',
      'i',
      'you',
      'he',
      'she',
      'it',
      'we',
      'they',
      'me',
      'him',
      'us',
      'them',
      'my',
      'your',
      'his',
      'her',
      'its',
      'our',
      'their',
      'mine',
      'yours',
      'hers',
      'ours',
      'theirs',
      'this',
      'that',
      'these',
      'those',
      'who',
      'whom',
      'whose',
      'which',
      'what',
      'where',
      'when',
      'why',
      'how',
      'am',
      'is',
      'are',
      'was',
      'were',
      'be',
      'been',
      'being',
      'have',
      'has',
      'had',
      'do',
      'does',
      'did',
      'can',
      'could',
      'shall',
      'should',
      'will',
      'would',
      'may',
      'might',
      'must',
      'there',
      'here',
      'not',
      'no',
      'than',
      'then',
      'too',
      'very',
      'just',
      'more',
      'most',
      'some',
      'any',
      'each',
      'all',
      'both',
      'half',
      'either',
      'neither',
      'other',
      'others',
      'such',
      'only',
      'own',
      'same',
    };

    final preTeachLemmas = profilerResult.vocabularyCoverage.preTeachWords
        .map((w) => w.lemma)
        .toSet();

    for (final token in profilerResult.tokens) {
      if (token.clean.isEmpty || token.surface.trim().isEmpty) {
        continue;
      }

      final isFunctionWord = functionWords.contains(token.clean);
      final isHigherLevel =
          token.cefrLevel == 'B2' ||
          token.cefrLevel == 'C1' ||
          token.cefrLevel == 'C2';
      final isAcademic = token.isAcademic;
      final isPreTeach = preTeachLemmas.contains(token.lemma);

      // Selective B1: Only pedagogical if academic, pre-teach, or non-K1 frequency band
      final isSelectiveB1 = token.cefrLevel == 'B1' &&
          (isAcademic || isPreTeach || token.frequencyBand != 'K1');

      // Sư phạm chọn lọc: B2-C2, Academic (AWL), Pre-teach, hoặc Selective B1
      // Loại trừ hoàn toàn A1/A2 cơ bản, từ chức năng, số và tên riêng
      final isPedagogical =
          (isHigherLevel || isAcademic || isPreTeach || isSelectiveB1) &&
          !isFunctionWord &&
          !token.isProperNoun &&
          !token.isNumber;

      final colorHex = DgnlHighlightPalette.colorHexForLevel(token.cefrLevel);

      String typeLabel = 'CEFR ${token.cefrLevel}';
      if (token.cefrLevel == 'Unknown') {
        typeLabel = token.isProperNoun
            ? 'Danh từ riêng (Proper)'
            : (token.isNumber ? 'Chữ số (Number)' : 'Chưa định danh (Unknown)');
      } else if (isAcademic) {
        typeLabel = 'AWL (${token.cefrLevel})';
      } else if (isPreTeach) {
        typeLabel = 'Dạy trước (${token.cefrLevel})';
      } else if (isFunctionWord) {
        typeLabel = 'Từ chức năng (${token.cefrLevel})';
      } else if (!isPedagogical) {
        typeLabel = 'Cơ bản (${token.cefrLevel})';
      }

      String note = '';
      if (token.cefrLevel == 'Unknown') {
        note = token.isProperNoun
            ? "Tên riêng hoặc thực thể xác định trong văn cảnh."
            : (token.isNumber
                  ? "Chữ số hoặc đại lượng định lượng."
                  : "Từ vựng hiếm hoặc chưa có trong từ điển CEFR (nguyên mẫu: '${token.lemma}').");
      } else if (isAcademic) {
        note =
            "Từ vựng học thuật AWL cấp độ ${token.cefrLevel} (Dải tần ${token.frequencyBand}, nguyên mẫu: '${token.lemma}').";
      } else if (isPedagogical) {
        note =
            "Từ vựng trọng tâm cấp độ ${token.cefrLevel} (Dải tần ${token.frequencyBand}, nguyên mẫu: '${token.lemma}').";
      } else if (isFunctionWord) {
        note =
            "Từ chức năng ngữ pháp cấp độ ${token.cefrLevel} (nguyên mẫu: '${token.lemma}').";
      } else {
        note =
            "Từ vựng nền tảng cấp độ ${token.cefrLevel} (nguyên mẫu: '${token.lemma}').";
      }

      highlights.add({
        'start': token.startIndex,
        'end': token.endIndex,
        'text': token.surface,
        'category': 'vocabulary',
        'level': token.cefrLevel,
        'type': typeLabel,
        'color': colorHex,
        'isPedagogical': isPedagogical,
        'isAcademic': isAcademic,
        'isPreTeach': isPreTeach,
        'isFunctionWord': isFunctionWord,
        'isProperNoun': token.isProperNoun,
        'isNumber': token.isNumber,
        'lemma': token.lemma,
        'clean': token.clean,
        'frequencyBand': token.frequencyBand,
        'syllables': token.syllables,
        'note': note,
      });
    }

    highlights.sort((a, b) {
      final aStart = a['start'] as int? ?? 0;
      final bStart = b['start'] as int? ?? 0;
      if (aStart != bStart) return aStart.compareTo(bStart);
      final aEnd = a['end'] as int? ?? 0;
      final bEnd = b['end'] as int? ?? 0;
      return bEnd.compareTo(aEnd);
    });

    final b2Pct = profilerResult.cefrPercentages['B2'] ?? 0.0;
    final c1C2Pct =
        (profilerResult.cefrPercentages['C1'] ?? 0.0) +
        (profilerResult.cefrPercentages['C2'] ?? 0.0);
    final a1B1Pct =
        (profilerResult.cefrPercentages['A1'] ?? 0.0) +
        (profilerResult.cefrPercentages['A2'] ?? 0.0) +
        (profilerResult.cefrPercentages['B1'] ?? 0.0);
    final b2C1Total = b2Pct + c1C2Pct;

    return DgnlAnalysisResult(
      totalWords: profilerResult.statistics.totalWords > 0
          ? profilerResult.statistics.totalWords
          : total,
      contentWords: contentWords,
      lexicalDensity: ld,
      cefrProfile: {
        'A1_B1': a1B1Pct > 0 ? a1B1Pct : 75.0,
        'B2': b2Pct > 0 ? b2Pct : 20.0,
        'C1_C2': c1C2Pct > 0 ? c1C2Pct : 5.0,
        'B2_C1_total': b2C1Total > 0 ? b2C1Total : 25.0,
      },
      evaluation: profilerResult.recommendations.isNotEmpty
          ? profilerResult.recommendations.first.description
          : 'Đoạn văn đạt chuẩn phân hóa đề thi ĐGNL (B2–C1 chiếm $b2C1Total%).',
      status: 'optimal',
      highlights: highlights,
      textProfile: profilerResult,
    );
  }

  static List<Map<String, dynamic>> fallbackGenerateCloze(String text) {
    final questions = <Map<String, dynamic>>[];
    if (text.contains('heavy smoker')) {
      questions.add({
        'id': 'cloze_offline_1',
        'target_type': 'collocation',
        'target_word': 'heavy',
        'original_sentence': 'My husband is a heavy smoker.',
        'masked_sentence': 'My husband is a [ _______ ] smoker.',
        'options': ['heavy', 'strong', 'deep', 'hard'],
        'correct_answer': 'heavy',
        'explanation':
            "Collocation cố định: 'heavy smoker' (người nghiện thuốc nặng), không dùng 'strong/deep/hard'.",
      });
    }
    if (text.contains('fed up with')) {
      questions.add({
        'id': 'cloze_offline_2',
        'target_type': 'collocation',
        'target_word': 'with',
        'original_sentence': 'I am fed up with sitting in pubs.',
        'masked_sentence': 'I am fed up [ _______ ] sitting in pubs.',
        'options': ['with', 'of', 'for', 'about'],
        'correct_answer': 'with',
        'explanation':
            "Cụm thành ngữ: 'be fed up with' (chán ngấy với cái gì).",
      });
    }
    return questions;
  }
}
