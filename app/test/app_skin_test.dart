import 'package:conexa/core/theme/app_skin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('todas as skins tem ids e nomes unicos', () {
    expect(AppSkin.all.length, 37);
    expect(AppSkin.all.map((skin) => skin.id).toSet().length, 37);
    expect(AppSkin.all.map((skin) => skin.name).toSet().length, 37);
  });

  test('todas as skins mantem contraste legivel', () {
    for (final skin in AppSkin.all) {
      final palette = skin.toPalette();

      expect(
        _contrast(palette.ink, palette.canvas),
        greaterThanOrEqualTo(4.5),
        reason: 'texto sobre fundo: ${skin.name}',
      );
      expect(
        _contrast(palette.onPrimary, palette.primary),
        greaterThanOrEqualTo(4.5),
        reason: 'texto sobre primaria: ${skin.name}',
      );
      expect(
        _contrast(palette.onAccent, palette.accent),
        greaterThanOrEqualTo(4.5),
        reason: 'texto sobre destaque: ${skin.name}',
      );
      expect(
        _contrast(palette.muted, palette.canvas),
        greaterThanOrEqualTo(4.5),
        reason: 'texto secundario: ${skin.name}',
      );
      expect(
        _contrast(palette.ink, palette.surface),
        greaterThanOrEqualTo(4.5),
        reason: 'texto sobre superficie: ${skin.name}',
      );
      expect(
        _contrast(palette.primary, palette.canvas),
        greaterThanOrEqualTo(4.5),
        reason: 'primaria sobre fundo: ${skin.name}',
      );
    }
  });
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}
