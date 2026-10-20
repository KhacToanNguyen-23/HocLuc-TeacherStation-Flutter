import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

class HocLucBrandMark extends StatelessWidget {
  const HocLucBrandMark({super.key, this.size = 34});

  final double size;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/images/hocluc-mark-v2.svg',
    width: size,
    height: size,
    fit: BoxFit.contain,
    semanticsLabel: 'HocLuc',
  );
}
