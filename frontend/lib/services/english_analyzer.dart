import 'dart:ui';
import '../models/board_sticker.dart';

class EnglishSentenceAnalyzer {
  static const Set<String> commonVerbs = {
    'go', 'goes', 'went', 'gone',
    'read', 'reads', 'reading',
    'play', 'plays', 'played',
    'write', 'writes', 'wrote', 'written',
    'teach', 'teaches', 'taught',
    'learn', 'learns', 'learned',
    'run', 'runs', 'ran',
    'see', 'sees', 'saw', 'seen',
    'is', 'are', 'am', 'was', 'were', 'be', 'been',
    'have', 'has', 'had',
    'do', 'does', 'did',
    'like', 'likes', 'liked',
    'love', 'loves', 'loved',
    'eat', 'eats', 'ate', 'eaten',
    'explain', 'explains', 'explained',
  };

  static const Set<String> commonPronouns = {
    'i', 'you', 'he', 'she', 'it', 'we', 'they',
  };

  static const Set<String> commonNouns = {
    'student', 'students', 'teacher', 'teachers',
    'school', 'schools', 'book', 'books', 'cat', 'cats',
    'dog', 'dogs', 'piano', 'lesson', 'classroom',
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

      if (!foundSubject && (commonPronouns.contains(lower) || commonNouns.contains(lower) || (i == 0 && lower != 'the' && lower != 'a'))) {
        role = 'subject';
        foundSubject = true;
      } else if (!foundVerb && (commonVerbs.contains(lower) || lower.endsWith('s') || lower.endsWith('ed') || lower.endsWith('ing'))) {
        role = 'verb';
        foundVerb = true;
      } else if (foundVerb && !foundObject && (commonNouns.contains(lower) || (lower != 'to' && lower != 'in' && lower != 'at' && lower != 'on' && lower != 'the' && lower != 'a' && lower != 'an' && lower.length > 2))) {
        role = 'object';
        foundObject = true;
      }

      tokens.add({
        'text': w,
        'role': role,
      });
    }

    String issue = 'Cấu trúc S-V-O chuẩn xác.';
    if (cleanSentence.toLowerCase().contains('i go to school')) {
      issue = 'Thì hiện tại đơn (Simple Present): Diễn tả thói quen/hành động lặp đi lặp lại.';
    } else if (!foundVerb) {
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
}
