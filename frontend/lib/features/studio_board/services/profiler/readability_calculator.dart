import 'dart:math' as math;
import '../../domain/models/text_profile_models.dart';

class ReadabilityCalculator {
  /// Calculates the 6 standard English readability metrics.
  static List<ReadabilityMetricItem> calculateMetrics(TextStatistics stats) {
    final words = stats.totalWords;
    final sentences = math.max(1, stats.totalSentences);
    final syllables = stats.totalSyllables;
    final polysyllables = stats.totalPolysyllables;
    final complexWords = stats.totalComplexWords;
    final letters = stats.totalLetters;
    final characters = stats.totalLetters; // Alphanumeric count

    final isTooShort = words < 10;
    final shortNote = isTooShort
        ? 'Văn bản quá ngắn (< 10 từ). Chỉ số chỉ mang tính chất tham khảo sơ bộ, không đủ độ tin cậy thống kê.'
        : '';

    // 1. Flesch Reading Ease
    // Formula: 206.835 - 1.015 * (words / sentences) - 84.6 * (syllables / words)
    double fleschEase = 0.0;
    String fleschInterpretation = '';
    String fleschGrade = '';
    if (words > 0) {
      final asyl = syllables / words;
      final aslen = words / sentences;
      fleschEase = 206.835 - (1.015 * aslen) - (84.6 * asyl);
      fleschEase = double.parse(fleschEase.clamp(0.0, 100.0).toStringAsFixed(1));

      if (fleschEase >= 90.0) {
        fleschInterpretation = 'Rất dễ đọc (Thích hợp cho học sinh Tiểu học / Lớp 5).';
        fleschGrade = 'Lớp 5';
      } else if (fleschEase >= 80.0) {
        fleschInterpretation = 'Dễ đọc (Thích hợp cho học sinh THCS Lớp 6).';
        fleschGrade = 'Lớp 6';
      } else if (fleschEase >= 70.0) {
        fleschInterpretation = 'Tương đối dễ (Thích hợp cho học sinh THCS Lớp 7).';
        fleschGrade = 'Lớp 7';
      } else if (fleschEase >= 60.0) {
        fleschInterpretation = 'Tiêu chuẩn (Ngôn ngữ đàm thoại thường nhật, học sinh Lớp 8–9).';
        fleschGrade = 'Lớp 8–9';
      } else if (fleschEase >= 50.0) {
        fleschInterpretation = 'Tương đối khó (Thích hợp cho học sinh THPT Lớp 10–12).';
        fleschGrade = 'Lớp 10–12';
      } else if (fleschEase >= 30.0) {
        fleschInterpretation = 'Khó đọc (Văn bản học thuật, trình độ Đại học / ĐGNL / VSTEP B2–C1).';
        fleschGrade = 'Đại học';
      } else {
        fleschInterpretation = 'Rất khó / Chuyên ngành sâu (Văn kiện khoa học chuyên sâu, sau Đại học).';
        fleschGrade = 'Sau Đại học';
      }
    }

    final fleschItem = ReadabilityMetricItem(
      id: 'flesch_reading_ease',
      name: 'Flesch Reading Ease',
      score: fleschEase,
      gradeLevelEquivalent: fleschGrade,
      interpretation: fleschInterpretation,
      formula: '206.835 - 1.015 × (Tổng từ / Số câu) - 84.6 × (Tổng âm tiết / Tổng từ)',
      mainFactors: [
        'Độ dài trung bình của câu (ASL)',
        'Số âm tiết trung bình trên mỗi từ (ASW)',
      ],
      limitations: 'Thang điểm nghịch đảo (điểm càng cao càng dễ đọc). Nhạy cảm với câu ghép dài.',
      references: 'Flesch, R. (1948). A new readability yardstick. Journal of Applied Psychology.',
      isReliable: !isTooShort,
      reliabilityNote: shortNote,
    );

    // 2. Flesch–Kincaid Grade Level
    // Formula: 0.39 * (words / sentences) + 11.8 * (syllables / words) - 15.59
    double fkGrade = 0.0;
    if (words > 0) {
      final asyl = syllables / words;
      final aslen = words / sentences;
      fkGrade = (0.39 * aslen) + (11.8 * asyl) - 15.59;
      fkGrade = double.parse(math.max(0.0, fkGrade).toStringAsFixed(1));
    }
    final fkItem = ReadabilityMetricItem(
      id: 'flesch_kincaid_grade',
      name: 'Flesch–Kincaid Grade Level',
      score: fkGrade,
      gradeLevelEquivalent: 'Khối lớp ${fkGrade.round()}',
      interpretation: 'Tương đương trình độ lớp ${fkGrade.round()} trong hệ thống giáo dục phổ thông Hoa Kỳ.',
      formula: '0.39 × (Tổng từ / Số câu) + 11.8 × (Tổng âm tiết / Tổng từ) - 15.59',
      mainFactors: [
        'Độ dài câu trung bình',
        'Độ dài từ trung bình theo số âm tiết',
      ],
      limitations: 'Quy đổi theo hệ thống khối lớp Mỹ (K-12). Không phản ánh trực tiếp 1-1 với khung CEFR Châu Âu.',
      references: 'Kincaid, J. P., et al. (1975). Derivation of new readability formulas.',
      isReliable: !isTooShort,
      reliabilityNote: shortNote,
    );

    // 3. Gunning Fog Index
    // Formula: 0.4 * [ (words / sentences) + 100 * (complexWords / words) ]
    double fogIndex = 0.0;
    if (words > 0) {
      final aslen = words / sentences;
      final hardWordPercent = (complexWords / words) * 100.0;
      fogIndex = 0.4 * (aslen + hardWordPercent);
      fogIndex = double.parse(fogIndex.toStringAsFixed(1));
    }
    final fogItem = ReadabilityMetricItem(
      id: 'gunning_fog',
      name: 'Gunning Fog Index',
      score: fogIndex,
      gradeLevelEquivalent: 'Khối lớp ${fogIndex.round()}',
      interpretation: fogIndex < 8.0
          ? 'Đoạn văn dễ tiếp cận (Phù hợp học sinh THCS).'
          : (fogIndex <= 12.0
              ? 'Đoạn văn đạt chuẩn phân hóa THPT & tốt nghiệp.'
              : 'Đoạn văn phức tạp, nhiều từ đa âm tiết khó (Phù hợp thi ĐGNL / C1).'),
      formula: '0.4 × [ (Tổng từ / Số câu) + 100 × (Từ phức tạp ≥3 âm tiết / Tổng từ) ]',
      mainFactors: [
        'Tỷ lệ từ phức tạp (≥ 3 âm tiết không tính hậu tố thông thường)',
        'Độ dài trung bình của câu',
      ],
      limitations: 'Bỏ qua tên riêng và các từ đa âm tiết tạo bởi hậu tố ngữ pháp -ed, -es, -ing.',
      references: 'Gunning, R. (1952). The Technique of Clear Writing. McGraw-Hill.',
      isReliable: !isTooShort,
      reliabilityNote: shortNote,
    );

    // 4. SMOG Index (Simple Measure of Gobbledygook)
    // Formula: 1.0430 * sqrt(30 * polysyllables / sentences) + 3.1291
    double smog = 0.0;
    String smogLimitation = 'Công thức chuẩn yêu cầu mẫu văn bản tối thiểu 30 câu. Với đoạn trích ngắn, hệ thống áp dụng hệ số chuẩn hóa tỷ lệ.';
    if (words > 0) {
      final normalizedPolys = (polysyllables / sentences) * 30.0;
      smog = (1.0430 * math.sqrt(math.max(0.0, normalizedPolys))) + 3.1291;
      smog = double.parse(smog.toStringAsFixed(1));
    }
    final smogItem = ReadabilityMetricItem(
      id: 'smog_index',
      name: 'SMOG Index',
      score: smog,
      gradeLevelEquivalent: 'Khối lớp ${smog.round()}',
      interpretation: 'Đo lường số năm học tập cần thiết để đọc hiểu trọn vẹn 100% nội dung đoạn văn.',
      formula: '1.0430 × √(30 × Từ đa âm tiết / Số câu) + 3.1291',
      mainFactors: [
        'Mật độ từ đa âm tiết (Polysyllables ≥ 3 âm tiết)',
        'Số lượng câu của đoạn',
      ],
      limitations: smogLimitation,
      references: 'McLaughlin, G. H. (1969). SMOG grading: a new readability formula. Journal of Reading.',
      isReliable: !isTooShort && sentences >= 3,
      reliabilityNote: sentences < 3
          ? 'Đoạn văn có ít hơn 3 câu, chỉ số SMOG có độ lệch cao hơn văn bản đầy đủ.'
          : shortNote,
    );

    // 5. Coleman–Liau Index
    // Formula: 0.0588 * L - 0.296 * S - 15.8
    // L = average number of letters per 100 words
    // S = average number of sentences per 100 words
    double colemanLiau = 0.0;
    if (words > 0) {
      final l = (letters / words) * 100.0;
      final s = (sentences / words) * 100.0;
      colemanLiau = (0.0588 * l) - (0.296 * s) - 15.8;
      colemanLiau = double.parse(math.max(0.0, colemanLiau).toStringAsFixed(1));
    }
    final clItem = ReadabilityMetricItem(
      id: 'coleman_liau',
      name: 'Coleman–Liau Index',
      score: colemanLiau,
      gradeLevelEquivalent: 'Khối lớp ${colemanLiau.round()}',
      interpretation: 'Ước lượng độ khó dựa trên số ký tự ký tự cơ học thay vì âm tiết ngữ âm.',
      formula: '0.0588 × L - 0.296 × S - 15.8 (L: ký tự/100 từ, S: câu/100 từ)',
      mainFactors: [
        'Độ dài từ tính theo số lượng ký tự chữ cái',
        'Tần suất kết thúc câu trên 100 từ',
      ],
      limitations: 'Tính toán thuần túy trên độ dài chữ cái, có thể đánh giá cao các từ chuyên ngành ngắn nhưng hiếm.',
      references: 'Coleman, M., & Liau, T. L. (1975). A computer readability formula designed for machine scoring.',
      isReliable: !isTooShort,
      reliabilityNote: shortNote,
    );

    // 6. Automated Readability Index (ARI)
    // Formula: 4.71 * (characters / words) + 0.5 * (words / sentences) - 21.43
    double ari = 0.0;
    if (words > 0) {
      final cpw = characters / words;
      final wps = words / sentences;
      ari = (4.71 * cpw) + (0.5 * wps) - 21.43;
      ari = double.parse(math.max(0.0, ari).toStringAsFixed(1));
    }
    final ariItem = ReadabilityMetricItem(
      id: 'automated_readability_index',
      name: 'Automated Readability Index (ARI)',
      score: ari,
      gradeLevelEquivalent: 'Khối lớp ${ari.round()}',
      interpretation: ari <= 8.0
          ? 'Phù hợp học sinh độ tuổi 12–14 (THCS).'
          : (ari <= 12.0
              ? 'Phù hợp học sinh độ tuổi 15–18 (THPT).'
              : 'Phù hợp sinh viên Đại học hoặc người lớn (18+ tuổi).'),
      formula: '4.71 × (Ký tự chữ và số / Tổng từ) + 0.5 × (Tổng từ / Số câu) - 21.43',
      mainFactors: [
        'Ký tự chữ và số trên mỗi từ',
        'Số từ trung bình trên mỗi câu',
      ],
      limitations: 'Được thiết kế ban đầu cho văn bản kỹ thuật quân đội Mỹ, có xu hướng cho điểm hơi cao đối với câu dài.',
      references: 'Senter, R. J., & Smith, E. A. (1967). Automated readability index. AMRL-TR-66-20.',
      isReliable: !isTooShort,
      reliabilityNote: shortNote,
    );

    return [fleschItem, fkItem, fogItem, smogItem, clItem, ariItem];
  }
}

