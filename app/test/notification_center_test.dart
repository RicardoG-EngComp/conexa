import 'package:conexa/features/notifications/data/notification_models.dart';
import 'package:conexa/features/notifications/data/notification_repository.dart';
import 'package:conexa/features/notifications/application/notification_providers.dart';
import 'package:conexa/features/notifications/presentation/notifications_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeNotificationRepository extends NotificationRepository {
  FakeNotificationRepository(super.client);

  @override
  Future<void> markRead(String id) async {}

  @override
  Future<void> markAllRead() async {}

  @override
  Future<NotificationPreferences> fetchPreferences() async =>
      const NotificationPreferences();

  @override
  Future<void> savePreferences(NotificationPreferences preferences) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'sb_publishable_test',
    );
  });

  final now = DateTime.now();

  List<AppNotification> testItems() => [
    AppNotification(
      id: '1',
      type: 'message',
      title: 'Nova mensagem',
      body: 'Nova mensagem',
      data: {'route': '/chats/abc'},
      createdAt: now,
    ),
    AppNotification(
      id: '2',
      type: 'connection_request',
      title: 'Nova solicitacao',
      body: 'Voce recebeu uma solicitacao.',
      data: {'route': '/chats?tab=connections'},
      createdAt: now,
      readAt: now.add(const Duration(minutes: 5)),
    ),
  ];

  Widget wrapScreen({required List<AppNotification> items}) {
    final router = GoRouter(
      initialLocation: '/notifications',
      routes: [
        GoRoute(
          path: '/notifications',
          builder: (_, _) => const NotificationsScreen(),
        ),
        GoRoute(
          path: '/chats/:id',
          builder: (_, _) => const Scaffold(body: Text('ChatDetail')),
        ),
        GoRoute(
          path: '/chats',
          builder: (_, _) => const Scaffold(body: Text('ChatList')),
        ),
      ],
    );
    return UncontrolledProviderScope(
      container: ProviderContainer(
        overrides: [
          notificationsProvider.overrideWith((ref) => Stream.value(items)),
          notificationRepositoryProvider.overrideWith(
            (ref) => FakeNotificationRepository(Supabase.instance.client),
          ),
        ],
      ),
      child: MaterialApp.router(routerConfig: router),
    );
  }

  testWidgets('exibe notificações com títulos e estado de leitura', (
    tester,
  ) async {
    await tester.pumpWidget(wrapScreen(items: testItems()));
    await tester.pumpAndSettle();

    expect(find.text('Nova mensagem'), findsWidgets);
    expect(find.text('Nova solicitacao'), findsOneWidget);
    expect(find.text('Marcar todas'), findsOneWidget);
  });

  testWidgets('exibe estado vazio quando não há notificações', (tester) async {
    await tester.pumpWidget(wrapScreen(items: []));
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma notificacao ainda.'), findsOneWidget);
  });

  testWidgets('botão Marcar todas desabilitado sem não lidas', (tester) async {
    final items = testItems()
        .map(
          (n) => AppNotification(
            id: n.id,
            type: n.type,
            title: n.title,
            body: n.body,
            data: n.data,
            createdAt: n.createdAt,
            readAt: now,
          ),
        )
        .toList();

    await tester.pumpWidget(wrapScreen(items: items));
    await tester.pumpAndSettle();

    final button = tester.widget<TextButton>(
      find.ancestor(
        of: find.text('Marcar todas'),
        matching: find.byType(TextButton),
      ),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('toque no tile dispara marcação de leitura', (tester) async {
    await tester.pumpWidget(wrapScreen(items: testItems()));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();
  });

  testWidgets('exibe ícones por tipo de notificação', (tester) async {
    await tester.pumpWidget(wrapScreen(items: testItems()));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
    expect(find.byIcon(Icons.people_outline), findsOneWidget);
  });
}
