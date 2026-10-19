import 'package:flutter/material.dart';

@immutable
class SmartPenAnswerSelection {
  const SmartPenAnswerSelection({
    required this.pageNumber,
    required this.label,
    required this.bounds,
    required this.groupId,
  });

  final int pageNumber;
  final String label;
  final Rect bounds;
  final String groupId;
}
