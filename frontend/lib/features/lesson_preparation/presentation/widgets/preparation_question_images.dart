import 'package:flutter/material.dart';
import '../../domain/models/preparation_document.dart';
import 'preparation_asset_image.dart';

class PreparationQuestionImages extends StatelessWidget {
  const PreparationQuestionImages({
    super.key,
    required this.section,
    this.teacherAudience = true,
  });
  final PreparationMap section;
  final bool teacherAudience;
  @override
  Widget build(BuildContext context) {
    final bank = section['questionBank'];
    final images = preparationRows(
      bank is Map ? bank['images'] : null,
    ).where((image) => teacherAudience || image['private'] == false).toList();
    if (images.isEmpty) return const SizedBox.shrink();
    return ExpansionTile(
      title: Text(
        teacherAudience
            ? 'Hình câu hỏi và lời giải (${images.length})'
            : 'Hình câu hỏi (${images.length})',
      ),
      subtitle: teacherAudience
          ? const Text('Hình lời giải riêng chỉ có trong bản giáo viên.')
          : null,
      children: [
        for (final image in images)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  image['private'] == false
                      ? 'Hình câu hỏi / ngữ cảnh học sinh'
                      : 'Hình lời giải riêng — chỉ giáo viên',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                SizedBox(
                  height: 300,
                  child: PreparationAssetImage(
                    assetId: '${image['imageAssetId']}',
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
