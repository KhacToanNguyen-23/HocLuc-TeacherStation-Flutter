import 'package:teaching_companion/features/studio_board/presentation/widgets/studio_board_shortcuts.dart';
import 'package:flutter/material.dart';
import 'package:teaching_companion/core/theme/app_theme.dart';
import 'package:teaching_companion/features/studio_board/domain/models/studio_state.dart';
import 'package:teaching_companion/features/studio_board/presentation/interactive_chalkboard.dart';
import 'package:teaching_companion/features/studio_board/presentation/studio/studio_drawing_toolbar.dart';

// Isolated acceptance surface: uses production board, toolbar and StudioState.
// No account, backend connection or saved lesson is loaded.
void main() => runApp(const RepaintDemo());

class RepaintDemo extends StatefulWidget {
  const RepaintDemo({super.key});
  @override
  State<RepaintDemo> createState() => _RepaintDemoState();
}

class _RepaintDemoState extends State<RepaintDemo> {
  final studio = StudioState();
  @override
  void dispose() {
    studio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: AppTheme.light(),
    debugShowCheckedModeBanner: false,
    home: StudioBoardShortcuts(
      studio: studio,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ListenableBuilder(
              listenable: studio,
              builder: (context, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Whiteboard — kiểm tra sau sửa',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Widget thật của app • Dữ liệu demo riêng • Số nét: ${studio.strokes.length}',
                    style: const TextStyle(fontSize: 15),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Vẽ → Hoàn tác / Làm lại → Tẩy → Xóa trang. Dừng sau mỗi thao tác, không chạm thêm vào bảng.',
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: ColoredBox(
                        color: const Color(0xff1b2b25),
                        child: InteractiveChalkboard(studio: studio),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  StudioDrawingToolbar(studio: studio),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
