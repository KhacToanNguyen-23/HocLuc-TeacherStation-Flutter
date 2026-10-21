import 'package:flutter/material.dart';

/// Public lesson text on the board, independent of presenter notes and controls.
class LessonSectionCard extends StatelessWidget {
  const LessonSectionCard({super.key, required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: LayoutBuilder(
      builder: (context, box) => Align(
        alignment: Alignment.topLeft,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: box.maxWidth,
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 28,
                height: 1.4,
                color: Color(0xfff0f3ed),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
