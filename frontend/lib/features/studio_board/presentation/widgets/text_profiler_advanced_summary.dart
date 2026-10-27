import 'package:flutter/material.dart';

import '../../domain/models/text_profile_models.dart';
import '../../services/profiler/dictionary_enrichment_controller.dart';

class TextProfilerAdvancedSummary extends StatelessWidget {
  const TextProfilerAdvancedSummary({
    super.key,
    required this.profile,
    required this.passageId,
    required this.controller,
  });

  final TextProfileResult profile;
  final String passageId;
  final DictionaryEnrichmentController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final apiEntryCount = controller.apiDictionaryEntryCount(
        passageId,
        profile,
      );
      final difficultyPercent = controller.advancedDifficultyPercent(profile);
      return Container(
        key: const Key('vocabulary-difficulty-summary'),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0x1822c55e),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0x554ade80)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.insights_outlined,
                  size: 14,
                  color: Color(0xff4ade80),
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Vocabulary-weighted difficulty',
                    style: TextStyle(
                      color: Color(0xff4ade80),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '$difficultyPercent%',
                  style: const TextStyle(
                    color: Color(0xff4ade80),
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Based on offline CEFR C1/C2 and AWL metrics.',
              style: const TextStyle(color: Color(0xffcbd5e1), fontSize: 10),
            ),
            Text(
              'Unique dictionary entries found: $apiEntryCount · API entries do not change CEFR or difficulty.',
              style: TextStyle(
                color: Color(0xff94a3b8),
                fontSize: 9.5,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    },
  );
}
