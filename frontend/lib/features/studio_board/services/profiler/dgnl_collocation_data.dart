/// Phân loại hình thái của cụm từ Collocation / Cụm từ cố định học thuật
enum DgnlCollocationType {
  adjectivePreposition(
    'Adjective + Preposition Collocation',
    'Tính từ đi kèm giới từ cố định',
  ),
  verbInfinitive(
    'Verb + Infinitive Collocation',
    'Động từ đi kèm nguyên mẫu hoặc giới từ chỉ xu hướng/mục đích',
  ),
  academicDiscourse(
    'Academic Discourse Expression',
    'Cụm liên từ / biểu thức chuyển tiếp học thuật',
  ),
  nounCompound(
    'Compound Noun Collocation',
    'Từ ghép danh từ chuyên ngành / học thuật',
  ),
  verbPreposition(
    'Verb + Preposition Collocation',
    'Cụm động từ + giới từ học thuật',
  );

  final String label;
  final String description;
  const DgnlCollocationType(this.label, this.description);
}

class DgnlCollocationEntry {
  final String phrase;
  final DgnlCollocationType type;
  final String explanation;
  final String level;

  const DgnlCollocationEntry({
    required this.phrase,
    required this.type,
    required this.explanation,
    this.level = 'B2',
  });
}

/// Cơ sở dữ liệu và thuật toán trích xuất Collocation có cấu trúc
class DgnlCollocationLexicon {
  static const List<DgnlCollocationEntry> entries = [
    // 1. Adjective + Preposition
    DgnlCollocationEntry(
      phrase: 'sensitive to',
      type: DgnlCollocationType.adjectivePreposition,
      explanation:
          'Tính từ đi kèm giới từ: "sensitive to" (nhạy cảm/mẫn cảm với).',
      level: 'B2',
    ),
    DgnlCollocationEntry(
      phrase: 'fond of',
      type: DgnlCollocationType.adjectivePreposition,
      explanation:
          'Tính từ đi kèm giới từ: "fond of" (yêu thích/thích thú với cái gì).',
      level: 'B1',
    ),
    DgnlCollocationEntry(
      phrase: 'incapable of',
      type: DgnlCollocationType.adjectivePreposition,
      explanation:
          'Tính từ đi kèm giới từ: "incapable of" (không có khả năng làm gì).',
      level: 'B2',
    ),
    DgnlCollocationEntry(
      phrase: 'capable of',
      type: DgnlCollocationType.adjectivePreposition,
      explanation: 'Tính từ đi kèm giới từ: "capable of" (có khả năng làm gì).',
      level: 'B2',
    ),
    DgnlCollocationEntry(
      phrase: 'different from',
      type: DgnlCollocationType.adjectivePreposition,
      explanation: 'Tính từ đi kèm giới từ: "different from" (khác biệt với).',
      level: 'A2',
    ),
    DgnlCollocationEntry(
      phrase: 'similar to',
      type: DgnlCollocationType.adjectivePreposition,
      explanation: 'Tính từ đi kèm giới từ: "similar to" (tương tự với).',
      level: 'B1',
    ),
    DgnlCollocationEntry(
      phrase: 'responsible for',
      type: DgnlCollocationType.adjectivePreposition,
      explanation:
          'Tính từ đi kèm giới từ: "responsible for" (chịu trách nhiệm cho).',
      level: 'B1',
    ),
    DgnlCollocationEntry(
      phrase: 'essential to',
      type: DgnlCollocationType.adjectivePreposition,
      explanation:
          'Tính từ đi kèm giới từ: "essential to" (thiết yếu đối với).',
      level: 'B2',
    ),
    DgnlCollocationEntry(
      phrase: 'vital to',
      type: DgnlCollocationType.adjectivePreposition,
      explanation:
          'Tính từ đi kèm giới từ: "vital to" (đóng vai trò sống còn đối với).',
      level: 'B2',
    ),
    DgnlCollocationEntry(
      phrase: 'relevant to',
      type: DgnlCollocationType.adjectivePreposition,
      explanation:
          'Tính từ đi kèm giới từ: "relevant to" (liên quan trực tiếp tới).',
      level: 'B2',
    ),
    DgnlCollocationEntry(
      phrase: 'consistent with',
      type: DgnlCollocationType.adjectivePreposition,
      explanation:
          'Tính từ đi kèm giới từ: "consistent with" (nhất quán/phù hợp với).',
      level: 'B2',
    ),
    DgnlCollocationEntry(
      phrase: 'compatible with',
      type: DgnlCollocationType.adjectivePreposition,
      explanation:
          'Tính từ đi kèm giới từ: "compatible with" (tương thích với).',
      level: 'B2',
    ),
    DgnlCollocationEntry(
      phrase: 'associated with',
      type: DgnlCollocationType.adjectivePreposition,
      explanation:
          'Tính từ/phân từ đi kèm giới từ: "associated with" (gắn liền với/liên đới với).',
      level: 'B2',
    ),
    DgnlCollocationEntry(
      phrase: 'opposed to',
      type: DgnlCollocationType.adjectivePreposition,
      explanation:
          'Tính từ đi kèm giới từ: "opposed to" (phản đối/trái ngược với).',
      level: 'B2',
    ),
    DgnlCollocationEntry(
      phrase: 'aware of',
      type: DgnlCollocationType.adjectivePreposition,
      explanation:
          'Tính từ đi kèm giới từ: "aware of" (nhận thức được điều gì).',
      level: 'B1',
    ),
    DgnlCollocationEntry(
      phrase: 'careful not to',
      type: DgnlCollocationType.adjectivePreposition,
      explanation:
          'Cấu trúc tính từ: "careful not to" (cẩn trọng không làm gì).',
      level: 'B1',
    ),

    // 2. Verb + Infinitive / Semi-auxiliary / Preposition
    DgnlCollocationEntry(
      phrase: 'tend to',
      type: DgnlCollocationType.verbInfinitive,
      explanation:
          'Động từ chỉ xu hướng: "tend to" (có xu hướng làm gì / hay có đặc điểm gì).',
      level: 'B2',
    ),
    DgnlCollocationEntry(
      phrase: 'seem to',
      type: DgnlCollocationType.verbInfinitive,
      explanation:
          'Động từ bán trợ động từ: "seem to" (dường như/có vẻ như làm gì).',
      level: 'B1',
    ),
    DgnlCollocationEntry(
      phrase: 'appear to',
      type: DgnlCollocationType.verbInfinitive,
      explanation:
          'Động từ chỉ biểu hiện/xu hướng: "appear to" (dường như/hóa ra là).',
      level: 'B2',
    ),
    DgnlCollocationEntry(
      phrase: 'set out to',
      type: DgnlCollocationType.verbInfinitive,
      explanation: 'Cụm động từ: "set out to" (bắt đầu dự định làm gì).',
      level: 'B2',
    ),
    DgnlCollocationEntry(
      phrase: 'proved to be',
      type: DgnlCollocationType.verbInfinitive,
      explanation: 'Collocation: "proved to be" (chứng tỏ là / hóa ra là).',
      level: 'B2',
    ),
    DgnlCollocationEntry(
      phrase: 'lead to',
      type: DgnlCollocationType.verbPreposition,
      explanation: 'Cụm động từ + giới từ: "lead to" (dẫn đến/gây ra hệ quả).',
      level: 'B1',
    ),
    DgnlCollocationEntry(
      phrase: 'result in',
      type: DgnlCollocationType.verbPreposition,
      explanation: 'Cụm động từ + giới từ: "result in" (dẫn đến kết quả).',
      level: 'B2',
    ),
    DgnlCollocationEntry(
      phrase: 'result from',
      type: DgnlCollocationType.verbPreposition,
      explanation:
          'Cụm động từ + giới từ: "result from" (bắt nguồn từ nguyên nhân).',
      level: 'B2',
    ),
    DgnlCollocationEntry(
      phrase: 'contribute to',
      type: DgnlCollocationType.verbPreposition,
      explanation:
          'Cụm động từ + giới từ: "contribute to" (đóng góp vào/góp phần gây ra).',
      level: 'B2',
    ),
    DgnlCollocationEntry(
      phrase: 'rely on',
      type: DgnlCollocationType.verbPreposition,
      explanation: 'Cụm động từ + giới từ: "rely on" (dựa dẫm/tin cậy vào).',
      level: 'B1',
    ),
    DgnlCollocationEntry(
      phrase: 'depend on',
      type: DgnlCollocationType.verbPreposition,
      explanation: 'Cụm động từ + giới từ: "depend on" (phụ thuộc vào).',
      level: 'A2',
    ),
    DgnlCollocationEntry(
      phrase: 'focus on',
      type: DgnlCollocationType.verbPreposition,
      explanation:
          'Cụm động từ + giới từ: "focus on" (tập trung vào trọng tâm).',
      level: 'B1',
    ),

    // 3. Academic Discourse Expressions & Fixed Phrases
    DgnlCollocationEntry(
      phrase: 'as a result',
      type: DgnlCollocationType.academicDiscourse,
      explanation:
          'Cụm liên từ chỉ kết quả: "as a result" (kết quả là / do đó).',
      level: 'B1',
    ),
    DgnlCollocationEntry(
      phrase: 'according to',
      type: DgnlCollocationType.academicDiscourse,
      explanation:
          'Giới từ phức hợp trích dẫn: "according to" (theo như lời của/theo nguồn tin).',
      level: 'A2',
    ),
    DgnlCollocationEntry(
      phrase: 'in fact',
      type: DgnlCollocationType.academicDiscourse,
      explanation: 'Liên từ học thuật: "in fact" (trên thực tế là).',
      level: 'B1',
    ),
    DgnlCollocationEntry(
      phrase: 'take into account',
      type: DgnlCollocationType.academicDiscourse,
      explanation:
          'Cụm cố định: "take into account" (cân nhắc/tính đến yếu tố nào).',
      level: 'B2',
    ),
    DgnlCollocationEntry(
      phrase: 'play a vital role',
      type: DgnlCollocationType.academicDiscourse,
      explanation:
          'Collocation chuẩn: "play a vital role" (đóng vai trò thiết yếu).',
      level: 'B2',
    ),
    DgnlCollocationEntry(
      phrase: 'make a decision',
      type: DgnlCollocationType.academicDiscourse,
      explanation: 'Collocation chuẩn: "make a decision" (đưa ra quyết định).',
      level: 'A2',
    ),
    DgnlCollocationEntry(
      phrase: 'pay attention to',
      type: DgnlCollocationType.academicDiscourse,
      explanation:
          'Collocation cố định: "pay attention to" (chú ý đến điều gì).',
      level: 'B1',
    ),
    DgnlCollocationEntry(
      phrase: 'draw attention to',
      type: DgnlCollocationType.academicDiscourse,
      explanation:
          'Collocation cố định: "draw attention to" (thu hút sự chú ý vào).',
      level: 'B2',
    ),
    DgnlCollocationEntry(
      phrase: 'keep track of',
      type: DgnlCollocationType.academicDiscourse,
      explanation:
          'Collocation cố định: "keep track of" (theo dõi/ghi nhớ tiến trình).',
      level: 'B2',
    ),
    DgnlCollocationEntry(
      phrase: 'as soon as',
      type: DgnlCollocationType.academicDiscourse,
      explanation: 'Liên từ thời gian: "as soon as" (ngay khi).',
      level: 'A2',
    ),
    DgnlCollocationEntry(
      phrase: 'in terms of',
      type: DgnlCollocationType.academicDiscourse,
      explanation:
          'Cụm giới từ học thuật: "in terms of" (xét về mặt/về phương diện).',
      level: 'B2',
    ),
    DgnlCollocationEntry(
      phrase: 'due to',
      type: DgnlCollocationType.academicDiscourse,
      explanation:
          'Giới từ chỉ nguyên nhân: "due to" (bởi vì / do tác động của).',
      level: 'B1',
    ),
    DgnlCollocationEntry(
      phrase: 'in addition to',
      type: DgnlCollocationType.academicDiscourse,
      explanation:
          'Cụm liên từ bổ sung: "in addition to" (ngoài ra / bên cạnh điều gì).',
      level: 'B2',
    ),
    DgnlCollocationEntry(
      phrase: 'fed up with',
      type: DgnlCollocationType.academicDiscourse,
      explanation: 'Thành ngữ: "fed up with" (quá chán ngấy với điều gì).',
      level: 'B1',
    ),
    DgnlCollocationEntry(
      phrase: 'end in failure',
      type: DgnlCollocationType.academicDiscourse,
      explanation:
          'Collocation học thuật: "end in failure" (kết thúc trong thất bại).',
      level: 'B2',
    ),

    // 4. Common Noun Compounds & Domain Terms
    DgnlCollocationEntry(
      phrase: 'taste buds',
      type: DgnlCollocationType.nounCompound,
      explanation:
          'Từ ghép chuyên ngành sinh học: "taste buds" (các nụ vị giác trên lưỡi).',
      level: 'B2',
    ),
    DgnlCollocationEntry(
      phrase: 'passive smoking',
      type: DgnlCollocationType.nounCompound,
      explanation:
          'Thuật ngữ học thuật: "passive smoking" (hút thuốc thụ động).',
      level: 'B2',
    ),
    DgnlCollocationEntry(
      phrase: 'heavy smoker',
      type: DgnlCollocationType.nounCompound,
      explanation:
          'Cụm danh từ cố định: "heavy smoker" (người nghiện thuốc nặng).',
      level: 'B2',
    ),
    DgnlCollocationEntry(
      phrase: 'heart disease',
      type: DgnlCollocationType.nounCompound,
      explanation: 'Thuật ngữ y khoa: "heart disease" (bệnh lý tim mạch).',
      level: 'B1',
    ),
    DgnlCollocationEntry(
      phrase: 'lung cancer',
      type: DgnlCollocationType.nounCompound,
      explanation: 'Thuật ngữ y khoa: "lung cancer" (ung thư phổi).',
      level: 'B1',
    ),
    DgnlCollocationEntry(
      phrase: 'increased risk',
      type: DgnlCollocationType.nounCompound,
      explanation:
          'Collocation học thuật: "increased risk" (nguy cơ gia tăng).',
      level: 'B2',
    ),
    DgnlCollocationEntry(
      phrase: 'smoky environments',
      type: DgnlCollocationType.nounCompound,
      explanation: 'Collocation: "smoky environments" (môi trường khói thuốc).',
      level: 'B2',
    ),
    DgnlCollocationEntry(
      phrase: 'medical studies',
      type: DgnlCollocationType.nounCompound,
      explanation: 'Cụm danh từ: "medical studies" (các nghiên cứu y khoa).',
      level: 'B1',
    ),
    DgnlCollocationEntry(
      phrase: 'two-way communication',
      type: DgnlCollocationType.nounCompound,
      explanation:
          'Thuật ngữ ngôn ngữ học: "two-way communication" (giao tiếp hai chiều).',
      level: 'B2',
    ),
    DgnlCollocationEntry(
      phrase: 'turn-taking pattern',
      type: DgnlCollocationType.nounCompound,
      explanation:
          'Thuật ngữ ngôn ngữ: "turn-taking pattern" (quy tắc luân phiên lượt lời).',
      level: 'C1',
    ),
    DgnlCollocationEntry(
      phrase: 'deliberately chosen',
      type: DgnlCollocationType.adjectivePreposition,
      explanation:
          'Collocation trạng từ + phân từ: "deliberately chosen" (cố ý lựa chọn).',
      level: 'B2',
    ),
  ];

  /// Trích xuất toàn bộ các Collocation và cụm từ cố định trong văn bản,
  /// giữ nguyên vị trí offset (start, end) chính xác cho từng lần xuất hiện.
  static List<Map<String, dynamic>> extractCollocations(String text) {
    if (text.isEmpty) return const [];

    final highlights = <Map<String, dynamic>>[];
    final sortedEntries = List<DgnlCollocationEntry>.from(entries)
      ..sort((a, b) => b.phrase.length.compareTo(a.phrase.length));

    final matchedSpans = <({int start, int end})>[];

    for (final entry in sortedEntries) {
      // Biểu thức regex khớp ranh giới từ và khoảng trắng linh hoạt
      final escaped = RegExp.escape(
        entry.phrase,
      ).replaceAll(RegExp(r'\s+'), r'\s+');
      final reg = RegExp(r'\b' + escaped + r'\b', caseSensitive: false);

      for (final match in reg.allMatches(text)) {
        final start = match.start;
        final end = match.end;
        final matchedSubstring = text.substring(start, end);

        // Không cho phép collocation vắt ngang dấu chấm kết câu
        if (matchedSubstring.contains(RegExp(r'[.!?]'))) {
          continue;
        }

        // Tránh trùng lặp hoàn toàn với một cụm dài hơn đã nhận diện
        final isContained = matchedSpans.any(
          (s) => s.start <= start && s.end >= end,
        );
        if (isContained) {
          continue;
        }

        matchedSpans.add((start: start, end: end));

        highlights.add({
          'start': start,
          'end': end,
          'text': matchedSubstring,
          'category': 'collocation',
          'level': entry.level,
          'type': entry.type.label,
          'color': '#86efac',
          'note': entry.explanation,
        });
      }
    }

    // Sắp xếp thứ tự xuất hiện từ trái qua phải theo vị trí ký tự
    highlights.sort((a, b) => (a['start'] as int).compareTo(b['start'] as int));
    return highlights;
  }
}
