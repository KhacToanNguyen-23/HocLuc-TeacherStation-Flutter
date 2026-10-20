import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Google brand icon widget displaying the recognizable Google 'G'.
class GoogleBrandIcon extends StatelessWidget {
  const GoogleBrandIcon({super.key, this.size = 20});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: SvgPicture.asset(
        'assets/images/google-g.svg',
        width: size,
        height: size,
        fit: BoxFit.contain,
        semanticsLabel: 'Google',
      ),
    );
  }
}
