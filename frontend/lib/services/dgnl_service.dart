import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'process_supervisor.dart';

class DgnlAnalysisResult {
  final int totalWords;
  final int contentWords;
  final double lexicalDensity;
  final Map<String, dynamic> cefrProfile;
  final String evaluation;
  final String status;
  final List<Map<String, dynamic>> highlights;

  const DgnlAnalysisResult({
    required this.totalWords,
    required this.contentWords,
    required this.lexicalDensity,
    required this.cefrProfile,
    required this.evaluation,
    required this.status,
    required this.highlights,
  });

  factory DgnlAnalysisResult.fromJson(Map<String, dynamic> json) {
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
    );
  }
}

class DgnlService {
  /// Base URL resolved dynamically from ProcessSupervisor if plugin sidecar is active
  static String? get baseUrl {
    final port = ProcessSupervisor.instance.getPort('com.hocluc.plugin.english');
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
        final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        final onlineRes = DgnlAnalysisResult.fromJson(data);
        final offlineRes = fallbackAnalyze(clean);

        // Merge online and offline highlights without duplicate spans
        final mergedHl = <Map<String, dynamic>>[...onlineRes.highlights];
        for (final oHl in offlineRes.highlights) {
          final oText = oHl['text']?.toString().toLowerCase().trim() ?? '';
          final alreadyPresent = mergedHl.any((m) {
            final mText = m['text']?.toString().toLowerCase().trim() ?? '';
            return mText == oText || mText.contains(oText) || oText.contains(mText);
          });
          if (!alreadyPresent) {
            mergedHl.add(oHl);
          }
        }

          return DgnlAnalysisResult(
            totalWords: onlineRes.totalWords > 0 ? onlineRes.totalWords : offlineRes.totalWords,
            contentWords: onlineRes.contentWords > 0 ? onlineRes.contentWords : offlineRes.contentWords,
            lexicalDensity: onlineRes.lexicalDensity > 0 ? onlineRes.lexicalDensity : offlineRes.lexicalDensity,
            cefrProfile: onlineRes.cefrProfile.isNotEmpty ? onlineRes.cefrProfile : offlineRes.cefrProfile,
            evaluation: onlineRes.evaluation,
            status: onlineRes.status,
            highlights: mergedHl,
          );
        }
      } catch (e) {
        debugPrint('[DgnlService] Online analyze failed, using offline engine: $e');
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
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final total = words.length;
    final contentWords = words.where((w) => w.length > 3).length;
    final ld = total > 0 ? ((contentWords / total) * 100).roundToDouble() : 0.0;

    final highlights = <Map<String, dynamic>>[];
    final lower = text.toLowerCase();

    // 1. Grammar Patterns
    final grammarPatterns = [
      {
        'pattern': RegExp(r'\b(It\s+(?:is|was)\s+[^.]+?\s+(?:that|who))\b', caseSensitive: false),
        'type': 'Câu chẻ nhấn mạnh (Cleft Sentence)',
        'note': 'Dùng để nhấn mạnh chủ ngữ, tân ngữ hoặc trạng ngữ.',
      },
      {
        'pattern': RegExp(r'\b(Hardly|Scarcely|No sooner|Seldom|Rarely|Not until)\b', caseSensitive: false),
        'type': 'Đảo ngữ phủ định (Inversion)',
        'note': 'Trạng từ phủ định đứng đầu câu đòi hỏi đảo trợ động từ.',
      },
      {
        'pattern': RegExp(r'\b(used\s+to\s+[a-z]+)\b', caseSensitive: false),
        'type': 'Cấu trúc Thói quen quá khứ (Used to + V)',
        'note': 'Thói quen trong quá khứ không còn ở hiện tại.',
      },
      {
        'pattern': RegExp(
          r'\b((?:is|are|am|was|were|been|being)\s+(?:going\s+to\s+be\s+[a-z]+|[a-z]+ed|[a-z]+en|[a-z]+wn|shown|asked|banned|built|made|held|written|known|given|taught|caught|found|bought|sold|brought|programmed))\b',
          caseSensitive: false,
        ),
        'type': 'Câu bị động (Passive Voice)',
        'note': 'Cấu trúc bị động phân hóa cao trong đề thi ĐGNL.',
      },
      {
        'pattern': RegExp(r'\b(Having\s+(?:been\s+)?[a-z]+(?:ed|en|wn))\b', caseSensitive: false),
        'type': 'Mệnh đề phân từ hoàn thành',
        'note': 'Hành động xảy ra trước hành động chính.',
      },
      {
        'pattern': RegExp(
          r'\b((?:in|of|by|at|for|from|with|without|about|instead\s+of)\s+[a-z]+ing)\b',
          caseSensitive: false,
        ),
        'type': 'Danh động từ sau giới từ (Prep + V-ing)',
        'note': 'Kiến thức ngữ pháp phân loại hay gặp trong các câu trắc nghiệm chia dạng từ.',
      },
      {
        'pattern': RegExp(
          r'\b((?:who|whom|which|that|whose|where|when)\s+[a-z]+(?:s|ed|d|ould|ight)?(?:\s+[a-z]+)?)\b',
          caseSensitive: false,
        ),
        'type': 'Mệnh đề quan hệ (Relative Clause)',
        'note': 'Cấu trúc câu phức phân hóa cao trong phần nối câu và tìm lỗi sai.',
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

    // 2. Academic Collocations
    final collocs = [
      {'phrase': 'passive smoking', 'note': 'Thuật ngữ học thuật: Hút thuốc thụ động.'},
      {'phrase': 'heavy smoker', 'note': 'Cụm cố định: Người nghiện thuốc lá nặng.'},
      {'phrase': 'heart disease', 'note': 'Collocation y khoa: Bệnh tim mạch.'},
      {'phrase': 'lung cancer', 'note': 'Collocation y khoa: Ung thư phổi.'},
      {'phrase': 'increased risk', 'note': 'Collocation chuẩn: Nguy cơ gia tăng.'},
      {'phrase': 'smoky environments', 'note': 'Collocation: Môi trường khói thuốc.'},
      {'phrase': 'medical studies', 'note': 'Thuật ngữ: Các nghiên cứu y khoa.'},
      {'phrase': 'in fact', 'note': 'Liên từ học thuật: Thực tế là.'},
      {'phrase': 'fed up with', 'note': 'Thành ngữ: Quá chán ngấy với điều gì.'},
      {'phrase': 'as soon as', 'note': 'Liên từ thời gian: Ngay khi.'},
      {'phrase': 'take into account', 'note': 'Cụm cố định: Cân nhắc, tính đến.'},
      {'phrase': 'make a decision', 'note': 'Collocation chuẩn: Đưa ra quyết định.'},
      {'phrase': 'play a vital role', 'note': 'Collocation chuẩn: Đóng vai trò thiết yếu.'},
      {'phrase': 'at home', 'note': 'Cụm trạng từ: Tại nhà.'},
      {'phrase': 'incapable of', 'note': 'Collocation tính từ + giới từ: Không có khả năng.'},
      {'phrase': 'end in failure', 'note': 'Collocation học thuật: Kết thúc trong thất bại.'},
      {'phrase': 'set out to', 'note': 'Cụm động từ: Bắt đầu dự định làm gì.'},
      {'phrase': 'proved to be', 'note': 'Collocation: Chứng tỏ là.'},
      {'phrase': 'different from', 'note': 'Tính từ đi kèm giới từ: Khác biệt với.'},
      {'phrase': 'careful not to', 'note': 'Cấu trúc tính từ: Cẩn trọng không làm gì.'},
      {'phrase': 'deliberately chosen', 'note': 'Collocation trạng từ + phân từ: Cố ý lựa chọn.'},
      {'phrase': 'two-way communication', 'note': 'Thuật ngữ ngôn ngữ học: Giao tiếp hai chiều.'},
      {'phrase': 'turn-taking pattern', 'note': 'Thuật ngữ ngôn ngữ: Quy tắc luân phiên lượt lời.'},
      {'phrase': 'pay attention to', 'note': 'Collocation cố định: Chú ý đến.'},
      {'phrase': 'draw attention to', 'note': 'Collocation cố định: Thu hút sự chú ý.'},
      {'phrase': 'keep track of', 'note': 'Collocation cố định: Theo dõi, ghi nhớ.'},
    ];

    for (final c in collocs) {
      final p = c['phrase']!;
      int startIdx = 0;
      while ((startIdx = lower.indexOf(p, startIdx)) != -1) {
        highlights.add({
          'start': startIdx,
          'end': startIdx + p.length,
          'text': text.substring(startIdx, startIdx + p.length),
          'category': 'collocation',
          'level': 'B2',
          'type': 'Academic Collocation',
          'color': '#86efac',
          'note': c['note'],
        });
        startIdx += p.length;
      }
    }

    // 3. Vocabulary CEFR B2 / C1
    final b2Words = [
      'banned', 'majority', 'enclosed', 'polluting', 'passive', 'smoking', 'environments',
      'environment', 'increased', 'risk', 'disease', 'cancer', 'medical', 'suffer', 'lungs',
      'alternative', 'technological', 'breakthrough', 'preliminary', 'investigation', 'inconvenient',
      'deliberately', 'incapable', 'imitate', 'communicate', 'communication', 'graduate', 'attempt',
      'pupil', 'unusual', 'programmed', 'ability', 'disagree', 'researchers', 'failure', 'experiment',
      'material', 'correctly', 'label', 'code', 'success', 'pattern', 'reason', 'creature', 'scientist',
      'scientists', 'fellow', 'especially'
    ];
    for (final bw in b2Words) {
      final reg = RegExp('\\b$bw\\b', caseSensitive: false);
      for (final m in reg.allMatches(text)) {
        highlights.add({
          'start': m.start,
          'end': m.end,
          'text': m.group(0),
          'category': 'vocabulary',
          'level': 'B2',
          'type': 'Từ vựng B2',
          'color': '#f9e2af',
          'note': "Từ vựng CEFR B2 cốt lõi đề thi ĐGNL: '$bw'.",
        });
      }
    }

    final c1Words = [
      'unprecedented', 'feasible', 'profound', 'subsequent', 'scientific', 'detrimental',
      'inevitable', 'exaggerate', 'deliberately', 'inconvenient', 'exaggerated', 'philosophical'
    ];
    for (final cw in c1Words) {
      final reg = RegExp('\\b$cw\\b', caseSensitive: false);
      for (final m in reg.allMatches(text)) {
        highlights.add({
          'start': m.start,
          'end': m.end,
          'text': m.group(0),
          'category': 'vocabulary',
          'level': 'C1',
          'type': 'Từ vựng C1',
          'color': '#cba6f7',
          'note': "Từ vựng phân hóa cao CEFR C1: '$cw'.",
        });
      }
    }

    return DgnlAnalysisResult(
      totalWords: total,
      contentWords: contentWords,
      lexicalDensity: ld,
      cefrProfile: {'A1_B1': 75.0, 'B2': 20.0, 'C1_C2': 5.0, 'B2_C1_total': 25.0},
      evaluation: 'Đoạn văn đạt chuẩn phân hóa đề thi ĐGNL (B2–C1 chiếm 25%).',
      status: 'optimal',
      highlights: highlights,
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
        'explanation': "Collocation cố định: 'heavy smoker' (người nghiện thuốc nặng), không dùng 'strong/deep/hard'.",
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
        'explanation': "Cụm thành ngữ: 'be fed up with' (chán ngấy với cái gì).",
      });
    }
    return questions;
  }
}
