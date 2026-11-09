import 'package:conexa/features/notifications/application/notification_providers.dart';
import 'package:conexa/features/notifications/presentation/notification_bell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

  Widget wrapBell({required int unreadCount}) {
    return UncontrolledProviderScope(
      container: ProviderContainer(
        overrides: [
          unreadNotificationCountProvider.overrideWithValue(unreadCount),
        ],
      ),
      child: const MaterialApp(home: NotificationBell()),
    );
  }

  testWidgets('badge visível quando há não lidas', (tester) async {
    await tester.pumpWidget(wrapBell(unreadCount: 3));
    await tester.pumpAndSettle();

    expect(find.byType(NotificationBell), findsOneWidget);
    expect(find.byType(Badge), findsOneWidget);
    final badge = tester.widget<Badge>(find.byType(Badge));
    expect(badge.isLabelVisible, isTrue);
  });

  testWidgets('badge oculta quando não há não lidas', (tester) async {
    await tester.pumpWidget(wrapBell(unreadCount: 0));
    await tester.pumpAndSettle();

    final badge = tester.widget<Badge>(find.byType(Badge));
    expect(badge.isLabelVisible, isFalse);
  });

  testWidgets('contém IconButton com tooltip', (tester) async {
    await tester.pumpWidget(wrapBell(unreadCount: 0));
    await tester.pumpAndSettle();

    final iconButton = tester.widget<IconButton>(find.byType(IconButton));
    expect(iconButton.tooltip, 'Notificacoes');
  });
}
