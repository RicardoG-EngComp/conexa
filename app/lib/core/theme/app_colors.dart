import 'package:flutter/material.dart';

import 'app_skin.dart';

/// Paleta ativa do app. O tema e aplicado no inicio e ao trocar de skin.
class AppColors {
  AppColors._();

  static AppSkin _skin = AppSkin.conexa;
  static AppPalette _palette = AppSkin.conexa.toPalette();

  static AppSkin get skin => _skin;
  static AppPalette get palette => _palette;

  static void apply(AppSkin skin) {
    _skin = skin;
    _palette = skin.toPalette();
  }

  static Color get paper => _palette.canvas;
  static Color get surface => _palette.surface;
  static Color get ink => _palette.ink;
  static Color get primary => _palette.primary;
  static Color get primaryDark => _palette.primaryDark;
  static Color get onPrimary => _palette.onPrimary;
  static Color get teal => _palette.primary;
  static Color get tealDark => _palette.primaryDark;
  static Color get muted => _palette.muted;
  static Color get border => _palette.border;
  static Color get danger => _palette.danger;
  static Color get success => _palette.success;
  static Color get accent => _palette.accent;
  static Color get onAccent => _palette.onAccent;
  static bool get isDark => _palette.isDark;
}
