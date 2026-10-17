import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:http/http.dart' as http;
import '../models/board_sticker.dart';
import 'process_supervisor.dart';

class EnglishSentenceAnalyzer {
  static const Set<String> commonVerbs = {
    'go',
    'goes',
    'went',
    'gone',
    'read',
    'reads',
    'reading',
    'play',
    'plays',
    'played',
    'write',
    'writes',
    'wrote',
    'written',
    'teach',
    'teaches',
    'taught',
    'learn',
    'learns',
    'learned',
    'run',
    'runs',
    'ran',
    'see',
    'sees',
    'saw',
    'seen',
    'is',
    'are',
    'am',
    'was',
    'were',
    'be',
    'been',
    'have',
    'has',
    'had',
    'do',
    'does',
    'did',
    'like',
    'likes',
    'liked',
    'love',
    'loves',
    'loved',
    'hate',
    'hates',
    'hated',
    'eat',
    'eats',
    'ate',
    'eaten',
    'explain',
    'explains',
    'explained',
    'study',
    'studies',
    'want',
    'need',
    'dance',
    'sing',
  };

  static const Set<String> commonPronouns = {
    'i',
    'you',
    'u',
    'he',
    'she',
    'it',
    'we',
    'they',
    'me',
    'him',
    'her',
    'us',
    'them',
  };

  static const Set<String> commonNouns = {
    'student',
    'students',
    'teacher',
    'teachers',
    'school',
    'schools',
    'book',
    'books',
    'cat',
    'cats',
    'dog',
    'dogs',
    'piano',
    'lesson',
    'classroom',
    'park',
    'apples',
    'apple',
  };

  static const Set<String> commonAdverbs = {
    'quickly',
    'slowly',
    'happily',
    'carefully',
    'eagerly',
    'very',
    'always',
    'often',
    'never',
    'usually',
    'yesterday',
    'today',
    'now',
    'well',
    'badly',
    'clearly',
    'easily',
    'so',
    'much',
    'somuch',
    'hard',
    'fast',
    'really',
    'quite',
    'too',
  };

  static const Set<String> commonAdjectives = {
    'beautiful',
    'pretty',
    'happy',
    'good',
    'bad',
    'nice',
    'smart',
    'tall',
    'short',
    'great',
    'wonderful',
    'tired',
    'hungry',
    'fine',
    'rich',
    'poor',
    'ready',
    'busy',
    'late',
    'early',
    'cold',
    'hot',
    'ugly',
    'angry',
    'clean',
    'dirty',
    'strong',
    'weak',
    'fast',
    'slow',
  };

  static const Set<String> linkingVerbs = {
    'is',
    'am',
    'are',
    'was',
    'were',
    'be',
    'been',
    'look',
    'looks',
    'looked',
    'seem',
    'seems',
    'feel',
    'become',
  };

  static BoardSticker analyze({
    required String text,
    String pluginId = 'com.hocluc.plugin.english',
    Rect? targetRect,
  }) {
    final cleanSentence = text.trim();
    final words = cleanSentence.split(RegExp(r'\s+'));

    bool foundSubject = false;
    bool foundVerb = false;
    bool foundObject = false;

    final tokens = <Map<String, dynamic>>[];

    for (int i = 0; i < words.length; i++) {
      final w = words[i];
      final lower = w.replaceAll(RegExp(r'[^a-zA-Z]'), '').toLowerCase();
      String? role;

      if (words.length == 1) {
        // Standalone single word classification
        if (commonVerbs.contains(lower)) {
          role = 'verb';
        } else if (commonAdverbs.contains(lower)) {
          role = 'adverb';
        } else if (commonAdjectives.contains(lower)) {
          role = 'complement';
        } else {
          role = 'subject';
        }
      } else {
        // Full sentence S-V-O-A-C-Det-Prep analysis
        const commonDets = {
          'a',
          'an',
          'the',
          'some',
          'any',
          'this',
          'that',
          'these',
          'those',
          'my',
          'your',
          'his',
          'her',
          'our',
          'their',
        };
        const commonPreps = {
          'to',
          'in',
          'on',
          'at',
          'for',
          'with',
          'by',
          'from',
          'into',
          'about',
          'under',
          'over',
        };
        const commonConjs = {'and', 'but', 'or', 'because', 'so'};

        if (commonDets.contains(lower)) {
          role = 'det';
        } else if (commonPreps.contains(lower)) {
          role = 'prep';
        } else if (commonConjs.contains(lower)) {
          role = 'conj';
        } else if (!foundSubject &&
            (commonPronouns.contains(lower) ||
                commonNouns.contains(lower) ||
                (i == 0 && !commonVerbs.contains(lower)))) {
          role = 'subject';
          foundSubject = true;
        } else if (commonAdverbs.contains(lower) ||
            (lower.endsWith('ly') && !commonVerbs.contains(lower))) {
          role = 'adverb';
        } else if (!foundVerb &&
            (commonVerbs.contains(lower) ||
                lower.endsWith('s') ||
                lower.endsWith('ed') ||
                lower.endsWith('ing'))) {
          role = 'verb';
          foundVerb = true;
        } else if (foundVerb &&
            (commonAdjectives.contains(lower) ||
                (lower.endsWith('ful') || lower.endsWith('able')))) {
          role = 'complement';
        } else if (foundVerb &&
            !foundObject &&
            (lower == 'u' ||
                commonPronouns.contains(lower) ||
                commonNouns.contains(lower) ||
                lower.isNotEmpty)) {
          role = 'object';
          foundObject = true;
        }
      }

      tokens.add({'text': w, 'role': role});
    }

    String issue = 'Cấu trúc S-V-O chuẩn xác.';
    if (!foundVerb) {
      issue = 'Lưu ý: Câu có thể đang thiếu động từ chính (Verb).';
    } else if (!foundSubject) {
      issue = 'Lưu ý: Câu có thể đang thiếu chủ ngữ (Subject).';
    }

    return BoardSticker(
      id: 'sticker-${DateTime.now().millisecondsSinceEpoch}',
      type: pluginId,
      normalizedRect: targetRect ?? const Rect.fromLTWH(0.25, 0.22, 0.50, 0.20),
      rawText: cleanSentence,
      tokens: tokens,
      issues: [issue],
    );
  }

  static Future<List<Map<String, dynamic>>> analyzeTokensWithBackend(
    String text,
  ) async {
    final port = ProcessSupervisor.instance.getPort(
      'com.hocluc.plugin.english',
    );
    if (port == null) return analyze(text: text).tokens;

    try {
      final res = await http
          .post(
            Uri.parse('http://127.0.0.1:$port/analyze-svo'),
            body: {'text': text},
          )
          .timeout(const Duration(milliseconds: 5000));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final rawTokens = data['tokens'] as List?;
        if (rawTokens != null && rawTokens.isNotEmpty) {
          return rawTokens.map((t) {
            final word = t['word']?.toString() ?? '';
            final roleStr = t['role']?.toString().toLowerCase();
            String? role;
            if (roleStr == 'subject') {
              role = 'subject';
            } else if (roleStr == 'verb') {
              role = 'verb';
            } else if (roleStr == 'object') {
              role = 'object';
            } else if (roleStr == 'adverb') {
              role = 'adverb';
            } else if (roleStr == 'complement') {
              role = 'complement';
            } else if (roleStr == 'det' || roleStr == 'determiner') {
              role = 'det';
            } else if (roleStr == 'prep' || roleStr == 'preposition') {
              role = 'prep';
            } else if (roleStr == 'conj' || roleStr == 'conjunction') {
              role = 'conj';
            }
            return {'text': word, 'role': role};
          }).toList();
        }
      }
    } catch (_) {
      // Fallback to local analyzer
    }
    return analyze(text: text).tokens;
  }

  static Future<Map<String, dynamic>?> analyzeWithOcr(
    Uint8List pngBytes,
  ) async {
    final port = ProcessSupervisor.instance.getPort(
      'com.hocluc.plugin.english',
    );
    if (port == null) return null;

    try {
      final uri = Uri.parse('http://127.0.0.1:$port/analyze-svo');
      final request = http.MultipartRequest('POST', uri);
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          pngBytes,
          filename: 'strokes.png',
        ),
      );
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 10),
      );
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final originalText = (data['original_text'] as String?)?.trim() ?? '';
        final rawTokens = data['tokens'] as List?;
        if (originalText.isNotEmpty &&
            rawTokens != null &&
            rawTokens.isNotEmpty) {
          final tokens = rawTokens.map((t) {
            final word = t['word']?.toString() ?? '';
            final roleStr = t['role']?.toString().toLowerCase();
            String? role;
            if (roleStr == 'subject') {
              role = 'subject';
            } else if (roleStr == 'verb') {
              role = 'verb';
            } else if (roleStr == 'object') {
              role = 'object';
            } else if (roleStr == 'adverb') {
              role = 'adverb';
            } else if (roleStr == 'complement') {
              role = 'complement';
            } else if (roleStr == 'det' || roleStr == 'determiner') {
              role = 'det';
            } else if (roleStr == 'prep' || roleStr == 'preposition') {
              role = 'prep';
            } else if (roleStr == 'conj' || roleStr == 'conjunction') {
              role = 'conj';
            }
            return {'text': word, 'role': role};
          }).toList();
          return {'text': originalText, 'tokens': tokens};
        }
      }
    } catch (_) {}
    return null;
  }
}
