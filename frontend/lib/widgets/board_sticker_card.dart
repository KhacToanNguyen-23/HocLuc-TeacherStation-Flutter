import 'package:flutter/material.dart';
import '../models/board_sticker.dart';

class BoardStickerCard extends StatelessWidget {
  const BoardStickerCard({
    super.key,
    required this.sticker,
    required this.onDelete,
    required this.onUpdateRect,
    this.parentSize,
  });

  final BoardSticker sticker;
  final VoidCallback onDelete;
  final ValueChanged<Rect> onUpdateRect;
  final Size? parentSize;

  Color _getRoleColor(String role) {
    switch (role.toUpperCase()) {
      case 'SUBJECT':
        return const Color(0xff89b4fa); // Catppuccin Blue
      case 'VERB':
        return const Color(0xfff38ba8); // Catppuccin Red/Pink
      case 'OBJECT':
        return const Color(0xfffab387); // Catppuccin Peach
      default:
        return const Color(0xffa6adc8); // Subtext
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) {
        if (parentSize == null ||
            parentSize!.width <= 0 ||
            parentSize!.height <= 0) {
          return;
        }
        final dxNorm = details.delta.dx / parentSize!.width;
        final dyNorm = details.delta.dy / parentSize!.height;
        final rect = sticker.normalizedRect;
        final nextLeft = (rect.left + dxNorm).clamp(
          0.0,
          1.0 - rect.width.clamp(0.05, 0.95),
        );
        final nextTop = (rect.top + dyNorm).clamp(
          0.0,
          1.0 - rect.height.clamp(0.05, 0.95),
        );
        onUpdateRect(Rect.fromLTWH(nextLeft, nextTop, rect.width, rect.height));
      },
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xf2181825), // Catppuccin Mantle dark card
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0x5589b4fa), width: 1.2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Drag Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: const BoxDecoration(
                  color: Color(0x22ffffff),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(9),
                    topRight: Radius.circular(9),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.push_pin,
                      size: 12,
                      color: Color(0xff89b4fa),
                    ),
                    const SizedBox(width: 4),
                    const Expanded(
                      child: Text(
                        'Cú pháp Tiếng Anh (S-V-O)',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xffcdd6f4),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    InkWell(
                      onTap: onDelete,
                      borderRadius: BorderRadius.circular(4),
                      child: const Padding(
                        padding: EdgeInsets.all(2),
                        child: Icon(
                          Icons.close,
                          size: 13,
                          color: Color(0xffbac2de),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Tokens & Grammar issues display
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Tokens Wrap
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: sticker.tokens.map((token) {
                        final role = (token['role'] as String? ?? 'OTHER')
                            .toUpperCase();
                        final text = token['text'] as String? ?? '';
                        final isKeyRole =
                            role == 'SUBJECT' ||
                            role == 'VERB' ||
                            role == 'OBJECT';
                        final color = _getRoleColor(role);

                        if (!isKeyRole) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 2,
                              vertical: 4,
                            ),
                            child: Text(
                              text,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xffa6adc8),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }

                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: color, width: 1),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                text,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                ),
                              ),
                              Text(
                                role[0], // S, V, O
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w900,
                                  color: color,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),

                    // Grammar issues
                    if (sticker.issues.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0x33f38ba8),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(0x88f38ba8),
                            width: 0.8,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: sticker.issues.map((issue) {
                            return Text(
                              issue,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xfff5e0dc),
                                height: 1.25,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
