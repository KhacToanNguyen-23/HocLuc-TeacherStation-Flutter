import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Left hero panel for auth modal showing exclusively the SVG illustration with zero text.
class AuthHeroPanel extends StatelessWidget {
  const AuthHeroPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF4F9BFF),
            Color(0xFF1E3A8A),
          ],
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: SvgPicture.asset(
        'assets/images/login-online-learning-v4.svg',
        fit: BoxFit.cover,
        alignment: Alignment.center,
        width: double.infinity,
        height: double.infinity,
      ),
    );
  }
}

