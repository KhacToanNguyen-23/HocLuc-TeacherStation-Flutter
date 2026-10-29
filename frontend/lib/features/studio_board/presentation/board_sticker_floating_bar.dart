import 'package:flutter/material.dart';
import 'package:teaching_companion/features/studio_board/domain/models/board_sticker.dart';

/// Canva-style Floating Action Bar for Selected Stickers (Image 3 NoteRenderer style).
/// Rendered on the top-most overlay layer so clicks are never clipped or intercepted.
class BoardStickerFloatingBar extends StatelessWidget {
  const BoardStickerFloatingBar({
    super.key,
    required this.sticker,
    required this.onDelete,
    this.onEdit,
    this.onDuplicate,
    this.onToggleRevolve,
    this.onDeselect,
    this.onSelect,
  });

  final BoardSticker sticker;
  final VoidCallback onDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onDuplicate;
  final VoidCallback? onToggleRevolve;
  final VoidCallback? onDeselect;
  final VoidCallback? onSelect;

  Widget _buildPillAction({
    required IconData icon,
    required String label,
    Color color = const Color(0xFF0F172A),
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPillDivider() {
    return Container(
      width: 1,
      height: 16,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: const Color(0xFFE2E8F0),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        height: 38.0,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F000000),
              blurRadius: 14,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // [ ✎ Sửa ]
              _buildPillAction(
                icon: Icons.edit_outlined,
                label: 'Sửa',
                color: const Color(0xFF0F172A),
                onTap: onEdit,
              ),
              _buildPillDivider(),

              // [ ⧉ Nhân bản ]
              _buildPillAction(
                icon: Icons.copy_all_outlined,
                label: 'Nhân bản',
                color: const Color(0xFF0F172A),
                onTap: onDuplicate,
              ),
              _buildPillDivider(),

              // [ 🗑 Xóa ]
              _buildPillAction(
                icon: Icons.delete_outline_rounded,
                label: 'Xóa',
                color: const Color(0xFFE11D48),
                onTap: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

