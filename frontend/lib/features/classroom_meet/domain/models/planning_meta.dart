class PlanningMeta {
  PlanningMeta({
    required this.id,
    required this.title,
    this.subject = 'Chung',
    this.pageCount = 1,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String subject;
  final int pageCount;
  final int createdAt;
  final int updatedAt;

  factory PlanningMeta.fromJson(Map<String, dynamic> json) {
    return PlanningMeta(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Kế hoạch bài giảng',
      subject: json['subject']?.toString() ?? 'Chung',
      pageCount: (json['pageCount'] as num?)?.toInt() ?? 1,
      createdAt:
          (json['createdAt'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
      updatedAt:
          (json['updatedAt'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'subject': subject,
    'pageCount': pageCount,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  String get formattedUpdatedAt {
    final dt = DateTime.fromMillisecondsSinceEpoch(updatedAt);
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year;
    return '$hour:$minute - $day/$month/$year';
  }

  PlanningMeta copyWith({
    String? id,
    String? title,
    String? subject,
    int? pageCount,
    int? createdAt,
    int? updatedAt,
  }) {
    return PlanningMeta(
      id: id ?? this.id,
      title: title ?? this.title,
      subject: subject ?? this.subject,
      pageCount: pageCount ?? this.pageCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
