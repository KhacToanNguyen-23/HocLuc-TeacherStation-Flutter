import 'package:flutter/material.dart';
import '../../constants/theme.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Left hero panel for auth modal showing exclusively the SVG illustration with zero text.
class AuthHeroPanel extends StatelessWidget {
  const AuthHeroPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: AppColors.surfaceMuted),
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
