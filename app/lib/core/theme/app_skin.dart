import 'package:flutter/material.dart';

/// Paleta escolhida pelo usuario. As tres cores sao a identidade visual;
/// os demais tons sao derivados para manter contraste e legibilidade.
class AppSkin {
  const AppSkin({
    required this.id,
    required this.name,
    required this.primary,
    required this.canvas,
    required this.accent,
  });

  final String id;
  final String name;
  final Color primary;
  final Color canvas;
  final Color accent;

  AppPalette toPalette() {
    final ink = _readableOn(canvas);
    final isDark = ink == Colors.white;
    var primaryAdjusted = _ensureContrast(primary, canvas, 4.5);
    var onPrimary = _readableOn(primaryAdjusted);
    if (contrast(onPrimary, primaryAdjusted) < 4.5) {
      primaryAdjusted = _ensureContrast(primaryAdjusted, onPrimary, 4.5);
      onPrimary = _readableOn(primaryAdjusted);
    }
    var accentAdjusted = _ensureContrast(accent, canvas, 4.5);
    var onAccent = _readableOn(accentAdjusted);
    if (contrast(onAccent, accentAdjusted) < 4.5) {
      accentAdjusted = _ensureContrast(accentAdjusted, onAccent, 4.5);
      onAccent = _readableOn(accentAdjusted);
    }
    final surface = Color.lerp(canvas, Colors.white, isDark ? 0.10 : 0.62)!;
    final border = Color.lerp(canvas, ink, 0.20)!;
    final muted = _ensureContrast(Color.lerp(canvas, ink, 0.62)!, canvas, 4.5);

    return AppPalette(
      primary: primaryAdjusted,
      primaryDark: Color.lerp(
        primaryAdjusted,
        isDark ? Colors.white : Colors.black,
        0.18,
      )!,
      onPrimary: onPrimary,
      canvas: canvas,
      surface: surface,
      ink: ink,
      muted: muted,
      border: border,
      accent: accentAdjusted,
      onAccent: onAccent,
      danger: isDark ? const Color(0xFFFF8A80) : const Color(0xFFB3261E),
      success: isDark ? const Color(0xFF7ED6A0) : const Color(0xFF2E7D5B),
      isDark: isDark,
    );
  }

  static const AppSkin conexa = AppSkin(
    id: 'skin_01',
    name: 'Cerúleo & Cereja',
    primary: Color(0xFF0693C6),
    canvas: Color(0xFFFCFCFF),
    accent: Color(0xFFD83995),
  );

  static const List<AppSkin> all = [
    conexa,
    AppSkin(
      id: 'skin_02',
      name: 'Meia-noite & Coral',
      primary: Color(0xFF02070A),
      canvas: Color(0xFF0297DE),
      accent: Color(0xFFFC734D),
    ),
    AppSkin(
      id: 'skin_04',
      name: 'Limão & Lavanda',
      primary: Color(0xFFFFF21A),
      canvas: Color(0xFF171717),
      accent: Color(0xFFA668FF),
    ),
    AppSkin(
      id: 'skin_05',
      name: 'Carvão & Tijolo',
      primary: Color(0xFF171717),
      canvas: Color(0xFF06110C),
      accent: Color(0xFFA31C18),
    ),
    AppSkin(
      id: 'skin_06',
      name: 'Café, Ocre & Champagne',
      primary: Color(0xFF584632),
      canvas: Color(0xFFC8792C),
      accent: Color(0xFFF4D9A0),
    ),
    AppSkin(
      id: 'skin_07',
      name: 'Tinta & Limão',
      primary: Color(0xFF101010),
      canvas: Color(0xFFFFFFFF),
      accent: Color(0xFFC8FF00),
    ),
    AppSkin(
      id: 'skin_08',
      name: 'Bordô & Tangerina',
      primary: Color(0xFF651424),
      canvas: Color(0xFFFFFFFF),
      accent: Color(0xFFFF5825),
    ),
    AppSkin(
      id: 'skin_09',
      name: 'Marinho & Coral',
      primary: Color(0xFF0E359D),
      canvas: Color(0xFFFFFFFF),
      accent: Color(0xFFFF606A),
    ),
    AppSkin(
      id: 'skin_10',
      name: 'Uva & Ouro',
      primary: Color(0xFF6410C9),
      canvas: Color(0xFFFFFF00),
      accent: Color(0xFFE9E9E9),
    ),
    AppSkin(
      id: 'skin_11',
      name: 'Vulcão & Negro',
      primary: Color(0xFFFF422A),
      canvas: Color(0xFFFFFFFF),
      accent: Color(0xFF000000),
    ),
    AppSkin(
      id: 'skin_12',
      name: 'Preto & Rosa Choque',
      primary: Color(0xFF000000),
      canvas: Color(0xFFFFFFFF),
      accent: Color(0xFFFF169C),
    ),
    AppSkin(
      id: 'skin_13',
      name: 'Cobalto & Laranja',
      primary: Color(0xFF0047F7),
      canvas: Color(0xFFFFFFFF),
      accent: Color(0xFFFA4802),
    ),
    AppSkin(
      id: 'skin_14',
      name: 'Negro, Amêndoa & Platina',
      primary: Color(0xFF000000),
      canvas: Color(0xFFECD3B5),
      accent: Color(0xFFE9E9E9),
    ),
    AppSkin(
      id: 'skin_15',
      name: 'Laranja & Verde-limão',
      primary: Color(0xFFFA4100),
      canvas: Color(0xFFFFFFFF),
      accent: Color(0xFF81F002),
    ),
    AppSkin(
      id: 'skin_16',
      name: 'Turquesa & Rosa',
      primary: Color(0xFF40C3D6),
      canvas: Color(0xFF36C7DD),
      accent: Color(0xFFEC3F97),
    ),
    AppSkin(
      id: 'skin_18',
      name: 'Lima & Esmeralda',
      primary: Color(0xFFC9FA64),
      canvas: Color(0xFF112C0F),
      accent: Color(0xFF13B195),
    ),
    AppSkin(
      id: 'skin_19',
      name: 'Rosa & Azul Klein',
      primary: Color(0xFFFC3B7F),
      canvas: Color(0xFFFEF1CF),
      accent: Color(0xFF0032A8),
    ),
    AppSkin(
      id: 'skin_20',
      name: 'Esmeralda & Rubi',
      primary: Color(0xFF018D3E),
      canvas: Color(0xFFFDF7E6),
      accent: Color(0xFFE71506),
    ),
    AppSkin(
      id: 'skin_21',
      name: 'Âmbar & Linho',
      primary: Color(0xFFFFC002),
      canvas: Color(0xFF000000),
      accent: Color(0xFFFEF3E6),
    ),
    AppSkin(
      id: 'skin_22',
      name: 'Magenta & Branco',
      primary: Color(0xFFFA0290),
      canvas: Color(0xFFFEFEFD),
      accent: Color(0xFF000000),
    ),
    AppSkin(
      id: 'skin_23',
      name: 'Floresta & Brasa',
      primary: Color(0xFF033E02),
      canvas: Color(0xFFFB0201),
      accent: Color(0xFF000000),
    ),
    AppSkin(
      id: 'skin_24',
      name: 'Floresta & Tangerina',
      primary: Color(0xFF075930),
      canvas: Color(0xFFFEFEFD),
      accent: Color(0xFFFE7C00),
    ),
    AppSkin(
      id: 'skin_25',
      name: 'Floresta Monocromática',
      primary: Color(0xFF075930),
      canvas: Color(0xFFFDFEFE),
      accent: Color(0xFF075930),
    ),
    AppSkin(
      id: 'skin_26',
      name: 'Ciano, Rosa & Limão',
      primary: Color(0xFF29E9FD),
      canvas: Color(0xFFFD94BA),
      accent: Color(0xFFF0FC54),
    ),
    AppSkin(
      id: 'skin_27',
      name: 'Branco & Vinho',
      primary: Color(0xFFFFFFFF),
      canvas: Color(0xFF780003),
      accent: Color(0xFFECC679),
    ),
    AppSkin(
      id: 'skin_28',
      name: 'Champagne, Vinho & Floresta',
      primary: Color(0xFFF5DABF),
      canvas: Color(0xFF6C151E),
      accent: Color(0xFF075930),
    ),
    AppSkin(
      id: 'skin_29',
      name: 'Linho & Floresta',
      primary: Color(0xFFF3EBD6),
      canvas: Color(0xFF1B422F),
      accent: Color(0xFF02110C),
    ),
    AppSkin(
      id: 'skin_30',
      name: 'Névoa & Safira',
      primary: Color(0xFFEAF3FB),
      canvas: Color(0xFFFDFEFE),
      accent: Color(0xFF1F5A8A),
    ),
    AppSkin(
      id: 'skin_31',
      name: 'Pêssego & Granito',
      primary: Color(0xFFFCE2D6),
      canvas: Color(0xFFF589A1),
      accent: Color(0xFF5D6066),
    ),
    AppSkin(
      id: 'skin_33',
      name: 'Grafite & Lima',
      primary: Color(0xFF000000),
      canvas: Color(0xFF585858),
      accent: Color(0xFFB2D902),
    ),
    AppSkin(
      id: 'skin_36',
      name: 'Verde-Água & Floresta',
      primary: Color(0xFF76C1A9),
      canvas: Color(0xFFFFFFFF),
      accent: Color(0xFF2A4B25),
    ),
    AppSkin(
      id: 'skin_37',
      name: 'Preto & Íris',
      primary: Color(0xFF020002),
      canvas: Color(0xFFFFFFFF),
      accent: Color(0xFF6E74F7),
    ),
    AppSkin(
      id: 'skin_38',
      name: 'Cobre & Ameixa',
      primary: Color(0xFFBB7B38),
      canvas: Color(0xFFFFFFFF),
      accent: Color(0xFF604D64),
    ),
    AppSkin(
      id: 'skin_39',
      name: 'Areia & Terracota',
      primary: Color(0xFFE7D0B3),
      canvas: Color(0xFFE0818E),
      accent: Color(0xFF76352B),
    ),
    AppSkin(
      id: 'skin_40',
      name: 'Cacau, Baunilha & Azul',
      primary: Color(0xFF39282C),
      canvas: Color(0xFFF9DF8E),
      accent: Color(0xFF9CB7D3),
    ),
    AppSkin(
      id: 'skin_41',
      name: 'Areia, Ameixa & Oliva',
      primary: Color(0xFFDFC9AC),
      canvas: Color(0xFF684453),
      accent: Color(0xFF776C4A),
    ),
    AppSkin(
      id: 'skin_42',
      name: 'Cacau & Ardósia',
      primary: Color(0xFF52312E),
      canvas: Color(0xFFE1C4A8),
      accent: Color(0xFF293345),
    ),
    AppSkin(
      id: 'skin_43',
      name: 'Gelo & Rubi',
      primary: Color(0xFFDFE7ED),
      canvas: Color(0xFFB20404),
      accent: Color(0xFFFFFFFF),
    ),
    AppSkin(
      id: 'skin_44',
      name: 'Champagne, Marinho & Vinho',
      primary: Color(0xFFF4E1D2),
      canvas: Color(0xFF1B2F68),
      accent: Color(0xFF640119),
    ),
    AppSkin(
      id: 'skin_45',
      name: 'Ameixa, Areia & Limão',
      primary: Color(0xFF381A56),
      canvas: Color(0xFFD2AE90),
      accent: Color(0xFFD9F301),
    ),
    AppSkin(
      id: 'skin_46',
      name: 'Oliva & Lilás',
      primary: Color(0xFF483B0F),
      canvas: Color(0xFFC99FC4),
      accent: Color(0xFFFDB0B7),
    ),
  ];

  static AppSkin byId(String? id) {
    return all.firstWhere((skin) => skin.id == id, orElse: () => conexa);
  }

  static Color _readableOn(Color background) {
    final white = contrast(Colors.white, background);
    final black = contrast(AppPalette.lightInk, background);
    return white >= black ? Colors.white : AppPalette.lightInk;
  }

  static Color _ensureContrast(Color color, Color background, double min) {
    if (contrast(color, background) >= min) return color;
    final target = _readableOn(background);
    for (var step = 1; step <= 20; step++) {
      final candidate = Color.lerp(color, target, step / 20)!;
      if (contrast(candidate, background) >= min) return candidate;
    }
    return target;
  }

  static double contrast(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final lighter = la > lb ? la : lb;
    final darker = la > lb ? lb : la;
    return (lighter + 0.05) / (darker + 0.05);
  }
}

class AppPalette {
  const AppPalette({
    required this.primary,
    required this.primaryDark,
    required this.onPrimary,
    required this.canvas,
    required this.surface,
    required this.ink,
    required this.muted,
    required this.border,
    required this.accent,
    required this.onAccent,
    required this.danger,
    required this.success,
    required this.isDark,
  });

  static const Color lightInk = Color(0xFF14130F);

  final Color primary;
  final Color primaryDark;
  final Color onPrimary;
  final Color canvas;
  final Color surface;
  final Color ink;
  final Color muted;
  final Color border;
  final Color accent;
  final Color onAccent;
  final Color danger;
  final Color success;
  final bool isDark;
}
