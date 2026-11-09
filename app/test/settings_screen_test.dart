import 'package:conexa/features/settings/presentation/settings_screen.dart';
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

  Widget wrapSettings() {
    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
        GoRoute(
          path: '/notification-preferences',
          builder: (_, _) => const Scaffold(body: Text('NotifsPref')),
        ),
        GoRoute(
          path: '/tutorial',
          builder: (_, _) => const Scaffold(body: Text('Tutorial')),
        ),
        GoRoute(
          path: '/profile-checklist',
          builder: (_, _) => const Scaffold(body: Text('Checklist')),
        ),
        GoRoute(
          path: '/help',
          builder: (_, _) => const Scaffold(body: Text('Help')),
        ),
        GoRoute(
          path: '/profile',
          builder: (_, _) => const Scaffold(body: Text('Profile')),
        ),
        GoRoute(
          path: '/change-password',
          builder: (_, _) => const Scaffold(body: Text('ChangePassword')),
        ),
        GoRoute(
          path: '/blocked-users',
          builder: (_, _) => const Scaffold(body: Text('Blocked')),
        ),
        GoRoute(
          path: '/admin',
          builder: (_, _) => const Scaffold(body: Text('Admin')),
        ),
      ],
    );
    return UncontrolledProviderScope(
      container: ProviderContainer(),
      child: MaterialApp.router(routerConfig: router),
    );
  }

  testWidgets('exibe Notificacoes em Ajustes', (tester) async {
    await tester.pumpWidget(wrapSettings());
    await tester.pumpAndSettle();

    expect(find.text('Notificacoes'), findsOneWidget);
  });

  testWidgets('exibe Como funciona em Ajustes', (tester) async {
    await tester.pumpWidget(wrapSettings());
    await tester.pumpAndSettle();

    expect(find.text('Como funciona'), findsOneWidget);
  });

  testWidgets('exibe Checklist do perfil em Ajustes', (tester) async {
    await tester.pumpWidget(wrapSettings());
    await tester.pumpAndSettle();

    expect(find.text('Checklist do perfil'), findsOneWidget);
  });

  testWidgets('exibe Ajuda e FAQ em Ajustes', (tester) async {
    await tester.pumpWidget(wrapSettings());
    await tester.pumpAndSettle();

    expect(find.text('Ajuda e FAQ'), findsOneWidget);
  });

  testWidgets('NÃO exibe Verificar atualizacao', (tester) async {
    await tester.pumpWidget(wrapSettings());
    await tester.pumpAndSettle();

    expect(find.text('Verificar atualizacao'), findsNothing);
  });
}
