import 'package:conexa/features/admin/presentation/admin_feedback_screen.dart';
import 'package:conexa/features/feedback/application/feedback_providers.dart';
import 'package:conexa/features/feedback/data/feedback_models.dart';
import 'package:conexa/features/reports/application/report_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrapAdmin({required bool isAdmin}) {
    return ProviderScope(
      overrides: [
        isAdminProvider.overrideWith((ref) async => isAdmin),
        adminFeedbackProvider.overrideWith(
          (ref, query) async => <FeedbackEntry>[],
        ),
      ],
      child: const MaterialApp(home: AdminFeedbackScreen()),
    );
  }

  testWidgets('exibe abas e estado vazio para admin', (tester) async {
    await tester.pumpWidget(wrapAdmin(isAdmin: true));
    await tester.pumpAndSettle();

    expect(find.text('Bugs'), findsOneWidget);
    expect(find.text('Sugestões'), findsOneWidget);
    expect(find.text('Abertos'), findsOneWidget);
    expect(find.text('Nenhum feedback neste filtro.'), findsOneWidget);
  });

  testWidgets('bloqueia nao admin', (tester) async {
    await tester.pumpWidget(wrapAdmin(isAdmin: false));
    await tester.pumpAndSettle();

    expect(find.text('Acesso restrito.'), findsOneWidget);
  });
}
