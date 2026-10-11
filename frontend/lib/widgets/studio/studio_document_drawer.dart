import 'package:flutter/material.dart';
import '../../constants/theme.dart';
import '../../models/studio_state.dart';
import 'studio_document_pages_list.dart';
import 'studio_document_files_list.dart';

class StudioDocumentDrawer extends StatelessWidget {
  const StudioDocumentDrawer({super.key, required this.studio});

  final StudioState studio;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: studio,
      builder: (context, _) {
        final isOpen = studio.showQuestionsDrawer;

        return Stack(
          children: [
            // Backdrop to dismiss on outside click
            if (isOpen)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => studio.setQuestionsDrawer(false),
                  behavior: HitTestBehavior.opaque,
                  child: Container(color: Colors.transparent),
                ),
              ),

            // Animated Compact Drawer Panel (width: 252)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              left: isOpen ? 0 : -256,
              top: 0,
              bottom: 0,
              width: 252,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xf70e1a15),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(14),
                    bottomRight: Radius.circular(14),
                  ),
                  border: Border.all(
                    color: const Color(0x33ffffff),
                    width: 1.2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x77000000),
                      blurRadius: 18,
                      offset: Offset(3, 0),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Compact Header
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Color(0x22ffffff)),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.collections_bookmark_outlined,
                            size: 15,
                            color: AppColors.lime,
                          ),
                          const SizedBox(width: 6),
                          const Expanded(
                            child: Text(
                              'Tài liệu giảng dạy',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xffe8eae6),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1.5,
                            ),
                            margin: const EdgeInsets.only(right: 4),
                            decoration: BoxDecoration(
                              color: const Color(0x28d4e8a6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${studio.pages.length} trang${studio.importedDocs.isNotEmpty ? " · ${studio.importedDocs.length} tệp" : ""}',
                              style: const TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                                color: AppColors.lime,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () => studio.setQuestionsDrawer(false),
                            borderRadius: BorderRadius.circular(4),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(
                                Icons.close,
                                size: 14,
                                color: Color(0xffa5b5a8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Scrollable Drawer Content (Pages + Divider + Documents)
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                        children: [
                          StudioDocumentPagesList(studio: studio),
                          StudioDocumentFilesList(studio: studio),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Sleek Collapsible Pull Tab on left edge of the chalkboard
            if (!isOpen)
              Positioned(
                left: 0,
                top: 36,
                child: Tooltip(
                  message:
                      'Tài liệu giảng dạy (${studio.importedDocs.length} tệp)',
                  child: InkWell(
                    onTap: () => studio.setQuestionsDrawer(true),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(7),
                      bottomRight: Radius.circular(7),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xee112019),
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(7),
                          bottomRight: Radius.circular(7),
                        ),
                        border: Border.all(color: const Color(0x33ffffff)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x55000000),
                            blurRadius: 6,
                            offset: Offset(2, 0),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.collections_bookmark_outlined,
                            size: 13,
                            color: AppColors.lime,
                          ),
                          if (studio.importedDocs.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xff2b4d3f),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                '${studio.importedDocs.length}',
                                style: const TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.lime,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.chevron_right,
                            size: 12,
                            color: Color(0xffa5b5a8),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
