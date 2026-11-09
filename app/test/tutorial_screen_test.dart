import 'package:conexa/features/onboarding/presentation/tutorial_screen.dart';
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

  Widget wrapTutorial() {
    final router = GoRouter(
      initialLocation: '/tutorial',
      routes: [
        GoRoute(path: '/tutorial', builder: (_, _) => const TutorialScreen()),
        GoRoute(
          path: '/feed',
          builder: (_, _) => const Scaffold(body: Text('Feed')),
        ),
      ],
    );
    return UncontrolledProviderScope(
      container: ProviderContainer(),
      child: MaterialApp.router(routerConfig: router),
    );
  }

  testWidgets('exibe primeira tela com título', (tester) async {
    await tester.pumpWidget(wrapTutorial());
    await tester.pumpAndSettle();

    expect(find.text('Bem-vindo ao Conexa'), findsOneWidget);
    expect(find.text('Pular'), findsOneWidget);
    expect(find.text('Proximo'), findsOneWidget);
  });

  testWidgets('avança para segunda tela ao tocar Proximo', (tester) async {
    await tester.pumpWidget(wrapTutorial());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Proximo'));
    await tester.pumpAndSettle();

    expect(find.text('Seu perfil'), findsOneWidget);
  });

  testWidgets('exibe botão Ativar notificações na última tela', (tester) async {
    await tester.pumpWidget(wrapTutorial());
    await tester.pumpAndSettle();

    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text('Proximo'));
      await tester.pumpAndSettle();
    }
    await tester.pumpAndSettle();

    expect(find.text('Ativar notificacoes'), findsOneWidget);
    expect(find.text('Comecar a usar'), findsOneWidget);
  });

  testWidgets('Pular leva ao feed', (tester) async {
    await tester.pumpWidget(wrapTutorial());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pular'));
    await tester.pumpAndSettle();

    expect(find.text('Feed'), findsOneWidget);
  });
}
