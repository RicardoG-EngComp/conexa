import 'package:conexa/features/feedback/application/feedback_providers.dart';
import 'package:conexa/features/feedback/presentation/bug_report_screen.dart';
import 'package:conexa/features/feedback/presentation/feedback_screen.dart';
import 'package:conexa/features/feedback/presentation/suggestion_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'sb_publishable_test',
    );
  });

  Widget wrapFeedback() {
    final router = GoRouter(
      initialLocation: '/feedback',
      routes: [
        GoRoute(path: '/feedback', builder: (_, _) => const FeedbackScreen()),
        GoRoute(
          path: '/feedback/bug',
          builder: (_, _) => const Scaffold(body: Text('Bug')),
        ),
        GoRoute(
          path: '/feedback/suggestion',
          builder: (_, _) => const Scaffold(body: Text('Suggestion')),
        ),
      ],
    );
    return UncontrolledProviderScope(
      container: ProviderContainer(
        overrides: [myFeedbackProvider.overrideWith((ref) async => [])],
      ),
      child: MaterialApp.router(routerConfig: router),
    );
  }

  testWidgets('exibe as duas opcoes e o estado vazio', (tester) async {
    await tester.pumpWidget(wrapFeedback());
    await tester.pumpAndSettle();

    expect(find.text('Reportar um problema'), findsOneWidget);
    expect(find.text('Enviar uma sugestão'), findsOneWidget);
    expect(find.text('Você ainda não enviou nenhum feedback.'), findsOneWidget);
  });

  testWidgets('bug valida titulo e descricao antes de enviar', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: BugReportScreen())),
    );
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.widgetWithText(FilledButton, 'Enviar relato'),
      find.byType(ListView),
      const Offset(0, -300),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Enviar relato'));
    await tester.pump();

    expect(
      find.text('Dê um título com pelo menos 5 caracteres.'),
      findsOneWidget,
    );
  });

  testWidgets('sugestao valida titulo e descricao antes de enviar', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SuggestionScreen())),
    );
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.widgetWithText(FilledButton, 'Enviar sugestão'),
      find.byType(ListView),
      const Offset(0, -300),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Enviar sugestão'));
    await tester.pump();

    expect(
      find.text('Dê um título com pelo menos 5 caracteres.'),
      findsOneWidget,
    );
  });
}
