import 'package:flutter/material.dart';
import '../../constants/theme.dart';
import '../../models/studio_state.dart';

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
              backgroundColor: const Color(0xff2d4c3d),
              foregroundColor: AppColors.lime,
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
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.rose600,
              ),
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
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isCurrent ? const Color(0x33d4e8a6) : const Color(0x14ffffff),
            border: Border.all(
              color: isCurrent ? AppColors.lime : const Color(0x22ffffff),
              width: isCurrent ? 1.4 : 1.0,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: isCurrent ? AppColors.lime : const Color(0x24ffffff),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: isCurrent ? const Color(0xff14221d) : const Color(0xffd0ded3),
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
                    color: isCurrent ? Colors.white : const Color(0xffe0eae2),
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
                      color: Color(0xffa5b5a8),
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
                        color: Color(0xffff7b7b),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 4),
              Icon(
                hasStrokes ? Icons.draw_outlined : Icons.crop_portrait,
                size: 12,
                color: isCurrent ? AppColors.lime : const Color(0x55ffffff),
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
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        margin: const EdgeInsets.only(top: 2, bottom: 4),
        decoration: BoxDecoration(
          color: const Color(0x18d4e8a6),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0x44d4e8a6)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 14, color: AppColors.lime),
            SizedBox(width: 4),
            Flexible(
              child: Text(
                'Thêm trang bài giảng',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.lime,
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
              color: AppColors.lime,
            ),
            const SizedBox(width: 5),
            const Text(
              'TRANG BÀI GIẢNG',
              style: TextStyle(
                fontSize: 9.5,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w700,
                color: AppColors.lime,
              ),
            ),
            const Spacer(),
            Text(
              'P.${studio.page + 1}/${studio.pages.length}',
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: Color(0xffa5b5a8),
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
