import '../../domain/models/text_profile_models.dart';

class TeacherRecommendationEngine {
  /// Generates deterministic, rule-based recommendations traceable to computed metrics.
  static List<PedagogicalRecommendation> generate({
    required TextStatistics stats,
    required Map<String, double> cefrPercentages,
    required List<ReadabilityMetricItem> readability,
    required LexicalDiversityResult diversity,
    required SyntacticComplexityResult syntax,
    required VocabularyCoverageResult coverage,
  }) {
    final list = <PedagogicalRecommendation>[];

    final b2PlusPercent = (cefrPercentages['B2'] ?? 0.0) +
        (cefrPercentages['C1'] ?? 0.0) +
        (cefrPercentages['C2'] ?? 0.0);
    final fleschItem = readability.firstWhere(
      (r) => r.id == 'flesch_reading_ease',
      orElse: () => readability.first,
    );

    // 1. Vocabulary Pre-Teaching Recommendation
    if (coverage.preTeachWords.isNotEmpty) {
      final sampleWords = coverage.preTeachWords.take(4).map((w) => "'${w.surface}' (${w.cefrLevel})").join(', ');
      list.add(
        PedagogicalRecommendation(
          category: 'vocabulary',
          title: 'Dạy trước từ vựng nâng cao (Pre-teach Vocabulary)',
          description: 'Đoạn văn chứa ${coverage.preTeachWords.length} từ vựng thuộc dải B2–C1 hoặc từ học thuật có thể gây trở ngại cho học sinh chưa vững nền tảng (ví dụ: $sampleWords).',
          priority: b2PlusPercent >= 20.0 ? 'high' : 'medium',
          actionableStep: 'Tổ chức hoạt động warm-up giải nghĩa hoặc ghép cặp từ đồng nghĩa/trái nghĩa cho danh sách từ vựng trọng tâm trước khi cho học sinh đọc văn bản.',
        ),
      );
    }

    // 2. Syntactic Complexity / Long Sentences Recommendation
    if (syntax.longSentences >= 2 || syntax.maxSentenceLength > 28) {
      list.add(
        PedagogicalRecommendation(
          category: 'syntax',
          title: 'Hướng dẫn bóc tách câu phức dài (> 25 từ)',
          description: 'Có ${syntax.longSentences} câu dài trong văn bản (câu dài nhất đạt ${syntax.maxSentenceLength} từ) với nhiều mệnh đề phụ thuộc hoặc mệnh đề quan hệ.',
          priority: 'high',
          actionableStep: 'Yêu cầu học sinh gạch chân Động từ chính (Main Verb) và xác định các liên từ/đại từ quan hệ để bóc tách câu dài thành các ý nhỏ hơn.',
        ),
      );
    }

    // 3. Passive Voice & Inversion Structures
    if (syntax.passiveVoiceCount >= 3) {
      list.add(
        PedagogicalRecommendation(
          category: 'syntax',
          title: 'Luyện tập nhận diện Cấu trúc Bị động (Passive Voice)',
          description: 'Văn bản sử dụng ${syntax.passiveVoiceCount} cấu trúc bị động, thường gặp trong các bài báo khoa học hoặc đề thi chuẩn hóa.',
          priority: 'medium',
          actionableStep: 'Đặt câu hỏi kiểm tra: "Ai/Cái gì thực hiện hành động này?" để đảm bảo học sinh không hiểu nhầm chủ thể và đối tượng tác động.',
        ),
      );
    }

    // 4. Readability Level & Target Student Guidance
    if (fleschItem.score < 50.0) {
      list.add(
        PedagogicalRecommendation(
          category: 'readability',
          title: 'Độ khó cao — Phù hợp học sinh Giỏi / Lớp 12 / ĐGNL',
          description: 'Điểm Flesch Reading Ease đạt ${fleschItem.score}/100 (${fleschItem.gradeLevelEquivalent}), phản ánh mật độ câu dài và từ học thuật cao.',
          priority: 'high',
          actionableStep: 'Nếu dùng cho học sinh THCS hoặc đại trà THPT, giáo viên nên cung cấp thêm bảng chú giải thuật ngữ hoặc câu hỏi đọc hiểu có gợi ý.',
        ),
      );
    } else if (fleschItem.score >= 70.0) {
      list.add(
        PedagogicalRecommendation(
          category: 'readability',
          title: 'Độ đọc hiểu dễ chịu — Thích hợp luyện tập đọc lướt (Skimming)',
          description: 'Điểm Flesch Reading Ease đạt ${fleschItem.score}/100, câu ngắn gọn và từ vựng quen thuộc (A1–B1 chiếm đa số).',
          priority: 'low',
          actionableStep: 'Thích hợp rèn luyện kỹ năng đọc lấy ý chính (Skimming), đọc quét chi tiết (Scanning) trong thời gian giới hạn.',
        ),
      );
    }

    // 5. Lexical Diversity & Vocabulary Retention
    if (diversity.ttr > 0.65 && stats.totalWords >= 50) {
      list.add(
        PedagogicalRecommendation(
          category: 'strategy',
          title: 'Độ phong phú từ vựng cao (TTR = ${diversity.ttr})',
          description: 'Văn bản ít bị lặp từ (MTLD = ${diversity.mtld}), học sinh sẽ tiếp xúc với nhiều cách diễn đạt phong phú.',
          priority: 'medium',
          actionableStep: 'Có thể tận dụng đoạn văn này để thiết kế bài tập điền từ đồng nghĩa (Paraphrasing) hoặc tạo câu hỏi Cloze Test.',
        ),
      );
    }

    return list;
  }
}

