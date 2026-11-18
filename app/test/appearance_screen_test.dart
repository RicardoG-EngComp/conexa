import 'package:conexa/core/theme/app_colors.dart';
import 'package:conexa/core/theme/app_skin.dart';
import 'package:conexa/core/theme/app_theme.dart';
import 'package:conexa/features/settings/presentation/appearance_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  tearDown(() => AppColors.apply(AppSkin.conexa));

  testWidgets('exibe as skins e aplica a selecionada', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const AppearanceScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cerúleo & Cereja'), findsOneWidget);
    await tester.tap(find.text('Meia-noite & Coral'));
    await tester.pumpAndSettle();

    expect(AppColors.skin.id, 'skin_02');
  });
}
