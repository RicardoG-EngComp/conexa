import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/notification_models.dart';
import '../data/notification_repository.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(Supabase.instance.client),
);

final notificationsProvider = StreamProvider.autoDispose<List<AppNotification>>(
  (ref) {
    return ref.read(notificationRepositoryProvider).watch();
  },
);

final unreadNotificationCountProvider = Provider<int>((ref) {
  final async = ref.watch(notificationsProvider);
  return async.maybeWhen(
    data: (items) => items.where((item) => item.isUnread).length,
    orElse: () => 0,
  );
});

final notificationPreferencesProvider =
    FutureProvider.autoDispose<NotificationPreferences>((ref) {
      return ref.read(notificationRepositoryProvider).fetchPreferences();
    });
