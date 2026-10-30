import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Tipografia: Newsreader (editorial) + IBM Plex Sans (corpo).
///
/// As fontes sao variaveis; usamos FontVariation para controlar o peso.
class AppTypography {
  AppTypography._();

  static const String serif = 'Newsreader';
  static const String sans = 'IBMPlexSans';

  static TextStyle _serif(double size, double weight, {double height = 1.15}) {
    return TextStyle(
      fontFamily: serif,
      fontSize: size,
      height: height,
      color: AppColors.ink,
      fontWeight: FontWeight.lerp(
        FontWeight.w100,
        FontWeight.w900,
        (weight - 100) / 800,
      ),
      fontVariations: [FontVariation('wght', weight)],
    );
  }

  static TextStyle _sans(double size, double weight, {double height = 1.5}) {
    return TextStyle(
      fontFamily: sans,
      fontSize: size,
      height: height,
      color: AppColors.ink,
      fontWeight: FontWeight.lerp(
        FontWeight.w100,
        FontWeight.w900,
        (weight - 100) / 800,
      ),
      fontVariations: [FontVariation('wght', weight)],
    );
  }

  static TextTheme get textTheme => TextTheme(
    displayLarge: _serif(40, 500, height: 1.05),
    displayMedium: _serif(34, 500, height: 1.1),
    headlineLarge: _serif(30, 500),
    headlineMedium: _serif(26, 500),
    titleLarge: _serif(22, 500),
    titleMedium: _sans(16, 600, height: 1.3),
    titleSmall: _sans(14, 600, height: 1.3),
    bodyLarge: _sans(16, 400),
    bodyMedium: _sans(14, 400),
    bodySmall: _sans(12, 400, height: 1.4),
    labelLarge: _sans(14, 600, height: 1.2),
    labelMedium: _sans(12, 600, height: 1.2),
    labelSmall: _sans(11, 600, height: 1.2),
  );
}
