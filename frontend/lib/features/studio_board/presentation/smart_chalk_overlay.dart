import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:teaching_companion/features/studio_board/domain/models/studio_state.dart';

class ChalkUnderlinePainter extends CustomPainter {
  ChalkUnderlinePainter({
    required this.tokens,
    required this.size,
    this.strokeHeight,
  });

  final List<ChalkWordToken> tokens;
  final Size size;
  final double? strokeHeight;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    for (final token in tokens) {
      if (token.color == Colors.transparent) continue;

      final rel = token.relativeRect;
      final tokenLeft = rel.left * canvasSize.width;
      final tokenWidth = rel.width * canvasSize.width;
      final tokenBottom = strokeHeight != null
          ? strokeHeight! + 2.0
          : canvasSize.height - 18.0;

      final paintHalo = Paint()
        ..color = const Color(0xb0000000)
        ..strokeWidth = 3.8
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      final paintChalk = Paint()
        ..color = token.color
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      // Draw dark contrast halo first (makes chalk pop on white PDF & dark chalkboard)
      canvas.drawLine(
        Offset(tokenLeft, tokenBottom),
        Offset(tokenLeft + tokenWidth, tokenBottom),
        paintHalo,
      );

      // Draw main chalk stroke
      canvas.drawLine(
        Offset(tokenLeft, tokenBottom),
        Offset(tokenLeft + tokenWidth, tokenBottom),
        paintChalk,
      );

      // Organic chalk texture particles / stipples
      final stipplePaint = Paint()
        ..color = token.color.withValues(alpha: 0.8)
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round;

      final steps = (tokenWidth / 6).clamp(3, 20).toInt();
      for (int i = 0; i < steps; i++) {
        final x = tokenLeft + (i * 6.0);
        final jitterY = tokenBottom + (math.sin(i * 1.5) * 0.8);
        canvas.drawCircle(Offset(x, jitterY), 0.7, stipplePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant ChalkUnderlinePainter oldDelegate) => true;
}

class SmartChalkOverlay extends StatelessWidget {
  const SmartChalkOverlay({
    super.key,
    required this.studio,
    this.targetAnnotations,
    this.onDelete,
  });

  final StudioState studio;
  final List<SmartChalkAnnotation>? targetAnnotations;
  final void Function(String id)? onDelete;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: studio,
      builder: (context, _) {
        if (!studio.chalkAnnotationsVisible) {
          return const SizedBox.shrink();
        }

        final annotations = targetAnnotations ?? studio.currentChalkAnnotations;
        if (annotations.isEmpty) return const SizedBox.shrink();

        return LayoutBuilder(
          builder: (context, constraints) {
            final canvasSize = Size(
              constraints.maxWidth,
              constraints.maxHeight,
            );

            return Stack(
              clipBehavior: Clip.none,
              children: [
                for (final a in annotations)
                  if (a.isVisible)
                    _AnnotationItemWidget(
                      annotation: a,
                      canvasSize: canvasSize,
                      studio: studio,
                      onDelete: onDelete,
                    ),
              ],
            );
          },
        );
      },
    );
  }
}

class _AnnotationItemWidget extends StatefulWidget {
  const _AnnotationItemWidget({
    required this.annotation,
    required this.canvasSize,
    required this.studio,
    this.onDelete,
  });

  final SmartChalkAnnotation annotation;
  final Size canvasSize;
  final StudioState studio;
  final void Function(String id)? onDelete;

  @override
  State<_AnnotationItemWidget> createState() => _AnnotationItemWidgetState();
}

class _AnnotationItemWidgetState extends State<_AnnotationItemWidget> {
  bool _isHovered = false;

  void _handleDelete() {
    if (widget.onDelete != null) {
      widget.onDelete!(widget.annotation.id);
    } else {
      widget.studio.removeChalkAnnotation(widget.annotation.id);
    }
  }

  void _handleEdit(BuildContext context) async {
    final initialText = widget.annotation.rawText.startsWith('Chờ xác nhận')
        ? ''
        : widget.annotation.rawText;
    final controller = TextEditingController(text: initialText);

    // Contextual one-tap word suggestions based on the last word or in-progress prefix
    List<String> getSuggestions(String current) {
      final trimmed = current.trim();
      final words = trimmed.split(RegExp(r'\s+'));
      final rawLast = words.isNotEmpty ? words.last : '';
      final lastWord = rawLast
          .replaceAll(RegExp(r'[^a-zA-Z]'), '')
          .toLowerCase();

      // 1. Prefix match for incomplete handwriting words (e.g. 'studen-' -> 'student')
      if (lastWord.isNotEmpty) {
        const teachingPool = [
          'student',
          'students',
          'teacher',
          'teachers',
          'school',
          'schools',
          'classroom',
          'English',
          'Math',
          'music',
          'football',
          'books',
          'happy',
          'ugly',
          'tired',
          'hungry',
          'angry',
          'beautiful',
          'smart',
          'playing',
          'learning',
          'studying',
          'reading',
          'writing',
          'doctor',
        ];
        final prefixMatches = teachingPool
            .where(
              (w) =>
                  w.toLowerCase().startsWith(lastWord) &&
                  w.toLowerCase() != lastWord,
            )
            .toList();
        if (prefixMatches.isNotEmpty) {
          return prefixMatches;
        }
      }

      // 2. Determiners / Articles: 'a', 'an', 'the'
      if (['a', 'an', 'the', 'this', 'that'].contains(lastWord)) {
        return [
          'student',
          'teacher',
          'school',
          'book',
          'pen',
          'cat',
          'dog',
          'doctor',
        ];
      }

      // 3. Adverb intensifiers
      if (['so', 'very', 'too', 'quite', 'really'].contains(lastWord)) {
        return [
          'ugly',
          'tired',
          'happy',
          'smart',
          'hungry',
          'angry',
          'beautiful',
          'hot',
          'cold',
          'good',
          'bad',
        ];
      }

      // 4. Auxiliary / Be verbs
      if (['is', 'are', 'am', 'was', 'were', 'be', 'been'].contains(lastWord)) {
        return [
          'a student',
          'so ugly',
          'happy',
          'tired',
          'smart',
          'studying',
          'learning',
          'teachers',
          'students',
        ];
      }

      // 5. Subject pronouns
      if (['they', 'i', 'we', 'you', 'he', 'she'].contains(lastWord)) {
        return [
          'am',
          'are',
          'is',
          'love',
          'like',
          'study',
          'play',
          'eat',
          'go',
          'read',
          'learn',
        ];
      }

      // 6. Action verbs
      if ([
        'studying',
        'learning',
        'playing',
        'teaching',
        'reading',
        'like',
        'love',
      ].contains(lastWord)) {
        return [
          'English',
          'Math',
          'music',
          'football',
          'books',
          'hard',
          'everyday',
        ];
      }

      return [
        'student',
        'ugly',
        'happy',
        'tired',
        'English',
        'Math',
        'are',
        'study',
      ];
    }

    final newText = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final suggestions = getSuggestions(controller.text);
          return AlertDialog(
            backgroundColor: const Color(0xff1e1e2e),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            title: const Row(
              children: [
                Icon(Icons.edit_note, color: Color(0xff89b4fa), size: 22),
                SizedBox(width: 8),
                Text(
                  'Chỉnh sửa câu tiếng Anh',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sửa lại câu hoặc chạm vào từ gợi ý để hoàn thiện nhanh:',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    onChanged: (_) => setDialogState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Ví dụ: They are so ugly',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xff181825),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xff45475a)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: Color(0xff89b4fa),
                          width: 1.5,
                        ),
                      ),
                    ),
                    onSubmitted: (val) => Navigator.of(ctx).pop(val),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Gợi ý từ ngữ cảnh (chạm 1-chạm):',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final word in suggestions)
                        InkWell(
                          onTap: () {
                            final current = controller.text.trim();
                            if (current.isEmpty) {
                              controller.text = word;
                            } else {
                              final parts = current.split(RegExp(r'\s+'));
                              final lastRaw = parts.last;
                              final lastClean = lastRaw
                                  .replaceAll(RegExp(r'[^a-zA-Z]'), '')
                                  .toLowerCase();
                              // If current ends with an incomplete prefix that word starts with, replace the incomplete word
                              if (lastClean.isNotEmpty &&
                                  (word.toLowerCase().startsWith(lastClean) ||
                                      lastRaw.endsWith('-'))) {
                                parts[parts.length - 1] = word;
                                controller.text = parts.join(' ');
                              } else {
                                controller.text = '$current $word';
                              }
                            }
                            controller.selection = TextSelection.fromPosition(
                              TextPosition(offset: controller.text.length),
                            );
                            setDialogState(() {});
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xff313244),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xff45475a),
                              ),
                            ),
                            child: Text(
                              word,
                              style: const TextStyle(
                                color: Color(0xffcdd6f4),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text(
                  'Hủy',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff89b4fa),
                  foregroundColor: const Color(0xff1e1e2e),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => Navigator.of(ctx).pop(controller.text),
                child: const Text(
                  'Cập nhật S-V-O',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
    );

    if (newText != null && newText.trim().isNotEmpty) {
      widget.studio.analyzeHandwritingWithVerifiedText(
        widget.annotation.normalizedBounds.center,
        newText.trim(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.annotation;
    final bounds = a.normalizedBounds;
    final offset = a.normalizedOffset;
    final canvasSize = widget.canvasSize;

    final pixelLeft = (bounds.left + offset.dx) * canvasSize.width;
    final pixelTop = (bounds.top + offset.dy) * canvasSize.height;
    final strokeWidth = (bounds.width * canvasSize.width).clamp(
      24.0,
      canvasSize.width,
    );
    final strokeHeight = (bounds.height * canvasSize.height).clamp(14.0, 300.0);
    final totalHeight = strokeHeight + 24.0;

    final isEraser = widget.studio.tool == 'erase';

    return Positioned(
      left: pixelLeft,
      top: pixelTop,
      width: strokeWidth,
      height: totalHeight,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapDown: (_) {
            if (isEraser) _handleDelete();
          },
          onPanStart: (_) {
            if (isEraser) _handleDelete();
          },
          onPanUpdate: (details) {
            if (isEraser) {
              _handleDelete();
              return;
            }
            final normDelta = Offset(
              details.delta.dx / canvasSize.width,
              details.delta.dy / canvasSize.height,
            );
            widget.studio.updateChalkAnnotationOffset(
              a.id,
              a.normalizedOffset + normDelta,
            );
          },
          child: SizedBox(
            width: strokeWidth,
            height: totalHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Chalk Underline Custom Painter
                Positioned.fill(
                  child: CustomPaint(
                    painter: ChalkUnderlinePainter(
                      tokens: a.tokens,
                      size: Size(strokeWidth, totalHeight),
                      strokeHeight: strokeHeight,
                    ),
                  ),
                ),

                // Word Role Badges (S, V, O, A, C or ... when pending)
                Positioned(
                  left: 0,
                  right: 0,
                  top: strokeHeight + 3.0,
                  height: 18,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (final token in a.tokens)
                        Positioned(
                          left: token.relativeRect.left * strokeWidth,
                          width: (token.relativeRect.width * strokeWidth).clamp(
                            20.0,
                            strokeWidth,
                          ),
                          height: 18,
                          child: Center(
                            child: GestureDetector(
                              onTap: () => _handleEdit(context),
                              child: Tooltip(
                                message:
                                    (token.role != null &&
                                        token.role!.isNotEmpty)
                                    ? '${token.word}: ${_getRoleDescription(token.role)}'
                                    : 'Bấm để nhập/chỉnh sửa câu',
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: token.color.withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: token.color,
                                      width: 1.0,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x88000000),
                                        blurRadius: 3,
                                        offset: Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    (token.role != null &&
                                            token.role!.isNotEmpty)
                                        ? _getRoleLetter(token.role)
                                        : '...',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      color: token.color,
                                      shadows: const [
                                        Shadow(
                                          color: Colors.black,
                                          blurRadius: 2,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Action buttons visible on hover or eraser mode
                if (_isHovered || isEraser)
                  Positioned(
                    top: -12,
                    right: -10,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Tooltip(
                          message: 'Chỉnh sửa câu',
                          child: GestureDetector(
                            onTap: () => _handleEdit(context),
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: const Color(0xdd1e1e2e),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xff89b4fa),
                                  width: 1.2,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black45,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.edit,
                                size: 12,
                                color: Color(0xff89b4fa),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Tooltip(
                          message: 'Xóa gạch chân S-V-O',
                          child: GestureDetector(
                            onTap: _handleDelete,
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: const Color(0xdd1e1e2e),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xfff38ba8),
                                  width: 1.2,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black45,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 13,
                                color: Color(0xfff38ba8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getRoleLetter(String? role) {
    if (role == null) return '';
    final r = role.toLowerCase();
    if (r == 'subject' || r == 's') return 'S';
    if (r == 'verb' || r == 'v') return 'V';
    if (r == 'object' || r == 'o') return 'O';
    if (r == 'adverb' || r == 'adverbial' || r == 'a') return 'A';
    if (r == 'complement' || r == 'c') return 'C';
    if (r == 'det' || r == 'determiner') return 'Det';
    if (r == 'prep' || r == 'preposition') return 'Prep';
    if (r == 'conj' || r == 'conjunction') return 'Conj';
    return role.toUpperCase();
  }

  String _getRoleDescription(String? role) {
    if (role == null) return '';
    final r = role.toLowerCase();
    if (r == 'subject' || r == 's') return 'Chủ ngữ [S]';
    if (r == 'verb' || r == 'v') return 'Động từ [V]';
    if (r == 'object' || r == 'o') return 'Tân ngữ [O]';
    if (r == 'adverb' || r == 'adverbial' || r == 'a') return 'Trạng ngữ [A]';
    if (r == 'complement' || r == 'c') return 'Bổ ngữ [C]';
    if (r == 'det' || r == 'determiner') return 'Mạo từ / Hạn định từ [Det]';
    if (r == 'prep' || r == 'preposition') return 'Giới từ [Prep]';
    if (r == 'conj' || r == 'conjunction') return 'Liên từ [Conj]';
    return role.toUpperCase();
  }
}

