import '../models/text_profile_models.dart';

class ExamProfiler {
  /// Compares text profile against standardized Vietnamese English exams:
  /// VSTEP (B1, B2, C1) and THPT Quốc Gia / ĐGNL.
  static List<ExamProfileComparison> evaluateExams({
    required TextStatistics stats,
    required Map<String, double> cefrPercentages,
    required List<ReadabilityMetricItem> readability,
    required LexicalDiversityResult diversity,
    required SyntacticComplexityResult syntax,
  }) {
    final list = <ExamProfileComparison>[];

    final b2Pct = cefrPercentages['B2'] ?? 0.0;
    final c1C2Pct =
        (cefrPercentages['C1'] ?? 0.0) + (cefrPercentages['C2'] ?? 0.0);
    final b2PlusPct = b2Pct + c1C2Pct;
    final b1PlusPct = b2PlusPct + (cefrPercentages['B1'] ?? 0.0);

    final fleschItem = readability.firstWhere(
      (r) => r.id == 'flesch_reading_ease',
      orElse: () => readability.first,
    );
    final flesch = fleschItem.score;
    final asl = stats.avgSentenceLength;

    // 1. VSTEP B1
    String vstepB1Fit = 'Phù hợp';
    if (b2PlusPct > 20.0 || flesch < 55.0 || asl > 20.0) {
      vstepB1Fit = 'Quá khó đối với mục tiêu B1';
    } else if (flesch >= 70.0 && b2PlusPct <= 10.0) {
      vstepB1Fit = 'Phù hợp tối ưu (Bài đọc 1–2 VSTEP)';
    } else {
      vstepB1Fit = 'Đạt chuẩn biên trên B1';
    }
    list.add(
      ExamProfileComparison(
        examName: 'VSTEP',
        targetLevel: 'Cấp độ B1 (Bậc 3 Khung 6 Bậc)',
        overallFit: vstepB1Fit,
        readabilityFit: 'Flesch $flesch (Chuẩn B1: 65–80)',
        vocabularyFit:
            'B1+ đạt ${b1PlusPct.toStringAsFixed(1)}% (Chuẩn B1: A1–B1 chiếm ≥ 80%)',
        sentenceComplexityFit:
            'Độ dài câu TB: ${asl.toStringAsFixed(1)} từ (Chuẩn B1: 12–16 từ)',
        notes: 'Thích hợp dùng cho Bài đọc 1 hoặc 2 trong bài thi Đọc hiểu VSTEP định dạng 4 phần.',
      ),
    );

    // 2. VSTEP B2
    String vstepB2Fit = 'Phù hợp';
    if (b2PlusPct >= 15.0 &&
        b2PlusPct <= 30.0 &&
        flesch >= 45.0 &&
        flesch <= 65.0) {
      vstepB2Fit = 'Phù hợp tối ưu (Bài đọc 2–3 VSTEP)';
    } else if (b2PlusPct < 15.0 && flesch > 65.0) {
      vstepB2Fit = 'Hơi dễ so với chuẩn phân hóa B2';
    } else {
      vstepB2Fit = 'Thử thách cao / Cận ngưỡng C1';
    }
    list.add(
      ExamProfileComparison(
        examName: 'VSTEP',
        targetLevel: 'Cấp độ B2 (Bậc 4 Khung 6 Bậc)',
        overallFit: vstepB2Fit,
        readabilityFit: 'Flesch $flesch (Chuẩn B2: 50–65)',
        vocabularyFit:
            'B2–C1 đạt ${b2PlusPct.toStringAsFixed(1)}% (Chuẩn B2: 15–25%)',
        sentenceComplexityFit:
            'Độ dài câu TB: ${asl.toStringAsFixed(1)} từ (Chuẩn B2: 16–22 từ)',
        notes: 'Phù hợp luyện kỹ năng đọc hiểu chuyên đề, suy luận ý tác giả và phân tích câu ghép.',
      ),
    );

    // 3. VSTEP C1
    String vstepC1Fit = 'Phù hợp';
    if (c1C2Pct >= 8.0 || (b2PlusPct >= 25.0 && flesch <= 45.0)) {
      vstepC1Fit = 'Phù hợp tối ưu (Bài đọc 4 VSTEP C1)';
    } else if (flesch > 55.0) {
      vstepC1Fit = 'Chưa đủ độ học thuật cho C1';
    } else {
      vstepC1Fit = 'Đạt chuẩn tiệm cận C1';
    }
    list.add(
      ExamProfileComparison(
        examName: 'VSTEP',
        targetLevel: 'Cấp độ C1 (Bậc 5 Khung 6 Bậc)',
        overallFit: vstepC1Fit,
        readabilityFit: 'Flesch $flesch (Chuẩn C1: 30–50)',
        vocabularyFit:
            'C1–C2 đạt ${c1C2Pct.toStringAsFixed(1)}%, Từ học thuật (AWL): ${diversity.academicPercentage}%',
        sentenceComplexityFit:
            'Độ dài câu TB: ${asl.toStringAsFixed(1)} từ (Chuẩn C1: > 20 từ, nhiều mệnh đề phụ)',
        notes: 'Thích hợp bài đọc học thuật nâng cao, phân hóa thí sinh đạt chuẩn giảng dạy Tiếng Anh.',
      ),
    );

    // 4. Kỳ thi THPT Quốc Gia / Đánh Giá Năng Lực (ĐGNL)
    String dgnlFit = 'Đoạn văn đọc hiểu tiêu chuẩn THPT';
    if (b2PlusPct >= 20.0 || syntax.longSentences >= 2) {
      dgnlFit = 'Phù hợp câu hỏi phân loại điểm 9–10 (ĐGNL / THPT)';
    } else if (b2PlusPct < 10.0) {
      dgnlFit = 'Phù hợp phần nhận biết — thông hiểu nền tảng';
    }
    list.add(
      ExamProfileComparison(
        examName: 'ĐGNL & THPT Quốc Gia',
        targetLevel: 'Đề thi Tuyển sinh Đại học & Tốt nghiệp THPT',
        overallFit: dgnlFit,
        readabilityFit:
            'Chỉ số đọc hiểu tương đương khối lớp ${readability[1].gradeLevelEquivalent}',
        vocabularyFit: 'Tỷ lệ từ B2–C1 chiếm ${b2PlusPct.toStringAsFixed(1)}%',
        sentenceComplexityFit:
            'Cấu trúc bị động (${syntax.passiveVoiceCount}), Mệnh đề quan hệ (${syntax.relativeClauseCount})',
        notes: 'Theo ma trận đề thi Bộ GD&ĐT, các câu hỏi phân loại điểm 9-10 thường khai thác từ vựng B2 và mệnh đề phức tạp.',
      ),
    );

    return list;
  }
}
