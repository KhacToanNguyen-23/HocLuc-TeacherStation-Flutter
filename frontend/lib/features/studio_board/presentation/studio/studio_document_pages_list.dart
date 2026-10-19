import 'package:flutter/material.dart';
import 'package:teaching_companion/constants/theme.dart';
import 'package:teaching_companion/models/studio_state.dart';

class StudioDocumentPagesList extends StatelessWidget {
  const StudioDocumentPagesList({super.key, required this.studio});

  final StudioState studio;

  Future<void> _showRenamePageDialog(BuildContext context, int index) async {
    final currentTitle = index < studio.pageTitles.length
        ? studio.pageTitles[index]
        : 'Trang ${index + 1}';
    final input = TextEditingController(text: currentTitle);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Đổi tên Trang ${index + 1}'),
        content: TextField(
          controller: input,
          autofocus: true,
          maxLength: 60,
          decoration: const InputDecoration(hintText: 'Nhập tiêu đề trang...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, input.text.trim()),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.overlayRaised,
              foregroundColor: AppColors.overlayAccent,
            ),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    input.dispose();
    if (result != null && result.isNotEmpty) {
      studio.renamePage(index, result);
    }
  }

  Future<void> _confirmDeletePage(BuildContext context, int index) async {
    if (studio.pages.length <= 1) return;
    final pageTitle = index < studio.pageTitles.length
        ? studio.pageTitles[index]
        : 'Trang ${index + 1}';
    final hasStrokes = studio.pages[index].isNotEmpty;

    if (hasStrokes) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Xác nhận xóa trang'),
          content: Text(
            'Trang "$pageTitle" đang có nét vẽ bài giảng. Bạn có chắc chắn muốn xóa không?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('Xóa trang'),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        studio.deletePage(index);
      }
    } else {
      studio.deletePage(index);
    }
  }

  Widget _buildPageItem(BuildContext context, int index) {
    final isCurrent = studio.page == index && studio.view == 'board';
    final label = index < studio.pageTitles.length
        ? studio.pageTitles[index]
        : 'Trang ${index + 1}';
    final hasStrokes = studio.pages[index].isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: InkWell(
        onTap: () => studio.change(() {
          studio.setPage(index);
          studio.view = 'board';
        }),
        borderRadius: BorderRadius.circular(AppRadii.control),
        child: AnimatedContainer(
          duration: AppMotion.duration(context, milliseconds: 150),
          curve: AppMotion.stateCurve,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isCurrent
                ? AppColors.overlaySelected
                : AppColors.overlayRaised,
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: isCurrent
                      ? AppColors.overlayAccent
                      : AppColors.overlayBorder,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: isCurrent
                          ? const Color(0xff14221d)
                          : AppColors.overlayText,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                    color: isCurrent ? Colors.white : AppColors.overlayText,
                  ),
                ),
              ),
              Tooltip(
                message: 'Đổi tên trang',
                child: InkWell(
                  onTap: () => _showRenamePageDialog(context, index),
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(
                      Icons.edit_outlined,
                      size: 13,
                      color: AppColors.overlayMuted,
                    ),
                  ),
                ),
              ),
              if (studio.pages.length > 1) ...[
                const SizedBox(width: 3),
                Tooltip(
                  message: 'Xóa trang này',
                  child: InkWell(
                    onTap: () => _confirmDeletePage(context, index),
                    borderRadius: BorderRadius.circular(4),
                    child: const Padding(
                      padding: EdgeInsets.all(2),
                      child: Icon(
                        Icons.delete_outline,
                        size: 13,
                        color: AppColors.errorSurface,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 4),
              Icon(
                hasStrokes ? Icons.draw_outlined : Icons.crop_portrait,
                size: 12,
                color: isCurrent
                    ? AppColors.overlayAccent
                    : AppColors.overlayMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddPageButton() {
    return InkWell(
      onTap: () => studio.change(() {
        studio.addPage();
        studio.view = 'board';
      }),
      borderRadius: BorderRadius.circular(AppRadii.control),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        margin: const EdgeInsets.only(top: 2, bottom: 4),
        decoration: BoxDecoration(
          color: AppColors.overlaySelected,
          borderRadius: BorderRadius.circular(AppRadii.control),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 14, color: AppColors.overlayAccent),
            SizedBox(width: 4),
            Flexible(
              child: Text(
                'Thêm trang bài giảng',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.overlayAccent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(
              Icons.layers_outlined,
              size: 13,
              color: AppColors.overlayAccent,
            ),
            const SizedBox(width: 5),
            const Text(
              'TRANG BÀI GIẢNG',
              style: TextStyle(
                fontSize: 9.5,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w700,
                color: AppColors.overlayAccent,
              ),
            ),
            const Spacer(),
            Text(
              'P.${studio.page + 1}/${studio.pages.length}',
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: AppColors.overlayMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        for (int i = 0; i < studio.pages.length; i++)
          _buildPageItem(context, i),
        _buildAddPageButton(),
      ],
    );
  }
}

