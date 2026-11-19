import 'package:flutter/material.dart';

class ConexaLogo extends StatelessWidget {
  const ConexaLogo({super.key, this.height = 32});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/branding/logo.png',
      height: height,
      width: height,
      semanticLabel: 'Conexa',
      filterQuality: FilterQuality.medium,
    );
  }
}
