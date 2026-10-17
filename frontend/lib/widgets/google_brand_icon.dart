import 'package:flutter/material.dart';

/// Google brand icon widget displaying the recognizable Google 'G'.
class GoogleBrandIcon extends StatelessWidget {
  const GoogleBrandIcon({super.key, this.size = 20});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      child: Text(
        'G',
        style: TextStyle(
          color: const Color(0xFF4285F4),
          fontSize: size * 0.9,
          fontWeight: FontWeight.w900,
          fontFamily: 'sans-serif',
          height: 1.0,
        ),
      ),
    );
  }
}
