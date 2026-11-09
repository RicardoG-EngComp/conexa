import 'package:conexa/features/discover/presentation/discover_screen.dart';
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

  Widget wrapDiscover() {
    final router = GoRouter(
      initialLocation: '/discover',
      routes: [
        GoRoute(path: '/discover', builder: (_, _) => const DiscoverScreen()),
        GoRoute(
          path: '/profile/:id',
          builder: (_, _) => const Scaffold(body: Text('Profile')),
        ),
      ],
    );
    return UncontrolledProviderScope(
      container: ProviderContainer(),
      child: MaterialApp.router(routerConfig: router),
    );
  }

  testWidgets('exibe título Descobrir', (tester) async {
    await tester.pumpWidget(wrapDiscover());
    await tester.pumpAndSettle();

    expect(find.text('Descobrir'), findsOneWidget);
  });

  testWidgets('exibe segmentos Pessoas e Estudos', (tester) async {
    await tester.pumpWidget(wrapDiscover());
    await tester.pumpAndSettle();

    expect(find.text('Pessoas'), findsOneWidget);
    expect(find.text('Estudos'), findsOneWidget);
  });
}
