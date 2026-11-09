import 'package:conexa/features/chat/presentation/chat_list_screen.dart';
import 'package:conexa/features/chat/data/chat_models.dart';
import 'package:conexa/features/chat/application/chat_providers.dart';
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

  Widget wrapChatList() {
    final router = GoRouter(
      initialLocation: '/chats',
      routes: [
        GoRoute(path: '/chats', builder: (_, _) => const ChatListScreen()),
        GoRoute(
          path: '/chats/:id',
          builder: (_, _) => const Scaffold(body: Text('ChatDetail')),
        ),
        GoRoute(
          path: '/profile/:id',
          builder: (_, _) => const Scaffold(body: Text('Profile')),
        ),
      ],
    );
    return UncontrolledProviderScope(
      container: ProviderContainer(
        overrides: [
          conversationsProvider.overrideWith(
            (ref) => Stream.value(<ConversationSummary>[]),
          ),
        ],
      ),
      child: MaterialApp.router(routerConfig: router),
    );
  }

  testWidgets('exibe abas Mensagens, Pedidos, Conexões', (tester) async {
    await tester.pumpWidget(wrapChatList());
    await tester.pumpAndSettle();

    expect(find.text('Mensagens'), findsOneWidget);
    expect(find.text('Pedidos'), findsOneWidget);
    expect(find.text('Conexões'), findsOneWidget);
  });

  testWidgets('exibe título Conversas', (tester) async {
    await tester.pumpWidget(wrapChatList());
    await tester.pumpAndSettle();

    expect(find.text('Conversas'), findsOneWidget);
  });

  testWidgets('exibe campo de busca', (tester) async {
    await tester.pumpWidget(wrapChatList());
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
  });
}
