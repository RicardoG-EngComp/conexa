import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ConexaLogo extends StatelessWidget {
  const ConexaLogo({super.key, this.height = 30});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/branding/logo.svg',
      height: height,
      width: height,
      semanticsLabel: 'Conexa',
    );
  }
}
