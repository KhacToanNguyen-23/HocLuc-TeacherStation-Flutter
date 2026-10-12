import 'package:flutter/material.dart';
import '../models/studio_state.dart';
import '../services/english_analyzer.dart';

class InBoardExtensionBar extends StatefulWidget {
  const InBoardExtensionBar({super.key, required this.studio});

  final StudioState studio;

  @override
  State<InBoardExtensionBar> createState() => _InBoardExtensionBarState();
}

class _InBoardExtensionBarState extends State<InBoardExtensionBar> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  static const List<String> _quickSamples = [
    'I go to school.',
    'The student reads a book.',
    'She plays the piano.',
  ];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: 'I go to school.');
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _analyzeAndPin(BuildContext context, String text) {
    final query = text.trim();
    if (query.isEmpty) return;

    final sticker = EnglishSentenceAnalyzer.analyze(
      text: query,
      pluginId:
          widget.studio.activePlugin?.manifest.id ??
          'com.hocluc.plugin.english',
    );

    widget.studio.addSticker(sticker);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Color(0xff86efac), size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Đã phân tích cú pháp và ghim thẻ "$query" lên bảng phấn!',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xff12221b),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plugin = widget.studio.activePlugin;
    if (plugin == null) return const SizedBox.shrink();

    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 820),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xf5101c17), // Deep slate green chalkboard tone
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x55d4e8a6), width: 1.2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 18,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Row: Plugin Badge, Input, Pin Button, Close Button
            Row(
              children: [
                // Plugin Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x28d4e8a6),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0x44d4e8a6)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.extension,
                        size: 14,
                        color: Color(0xffd4e8a6),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        plugin.manifest.name,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xffd4e8a6),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Inline Sentence Input Field
                Expanded(
                  child: Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: const Color(0x1fffffff),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0x33ffffff)),
                    ),
                    alignment: Alignment.centerLeft,
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        hintText:
                            'Nhập câu tiếng Anh... (ví dụ: I go to school.)',
                        hintStyle: TextStyle(
                          fontSize: 11,
                          color: Color(0xff8a9a8d),
                        ),
                      ),
                      onSubmitted: (val) => _analyzeAndPin(context, val),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Button: Analyze & Pin
                FilledButton.icon(
                  onPressed: () => _analyzeAndPin(context, _controller.text),
                  icon: const Icon(Icons.bolt, size: 14),
                  label: const Text(
                    'Phân tích & Ghim',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xff2d4c3d),
                    foregroundColor: const Color(0xffd4e8a6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 0,
                    ),
                    minimumSize: const Size(0, 32),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                      side: const BorderSide(color: Color(0x44d4e8a6)),
                    ),
                  ),
                ),
                const SizedBox(width: 4),

                // Close plugin button
                Tooltip(
                  message: 'Tắt tiện ích trên bảng',
                  child: InkWell(
                    onTap: () => widget.studio.closePlugin(),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.close,
                        size: 15,
                        color: Color(0xffa5b5a8),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Bottom Row: Quick sample chips
            const SizedBox(height: 5),
            Row(
              children: [
                const Text(
                  'Mẫu nhanh:',
                  style: TextStyle(
                    fontSize: 9.5,
                    color: Color(0xff8a9a8d),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final sample in _quickSamples) ...[
                          InkWell(
                            onTap: () {
                              _controller.text = sample;
                              _analyzeAndPin(context, sample);
                            },
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0x18ffffff),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: const Color(0x28ffffff),
                                ),
                              ),
                              child: Text(
                                sample,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xffd4e8a6),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
