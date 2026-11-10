import 'package:supabase_flutter/supabase_flutter.dart';

import 'notification_models.dart';

class NotificationRepository {
  NotificationRepository(this._client);

  final SupabaseClient _client;

  String? get _userId => _client.auth.currentUser?.id;

  Stream<List<AppNotification>> watch() {
    final userId = _userId;
    if (userId == null) return Stream.value(const []);
    return _client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map(
          (rows) => rows
              .map((row) => AppNotification.fromMap(row))
              .toList(growable: false),
        );
  }

  Future<void> markRead(String id) async {
    await _client.rpc(
      'mark_notification_read',
      params: {'p_notification_id': id},
    );
  }

  Future<void> markAllRead() async {
    await _client.rpc('mark_all_notifications_read');
  }

  Future<NotificationPreferences> fetchPreferences() async {
    final userId = _userId;
    if (userId == null) return const NotificationPreferences();
    final row = await _client
        .from('notification_preferences')
        .select('message_requests, messages, connections, studies, groups')
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) return const NotificationPreferences();
    return NotificationPreferences.fromMap(row);
  }

  Future<void> savePreferences(NotificationPreferences preferences) async {
    final userId = _userId;
    if (userId == null) return;
    await _client.from('notification_preferences').upsert({
      'user_id': userId,
      'message_requests': preferences.messageRequests,
      'messages': preferences.messages,
      'connections': preferences.connections,
      'studies': preferences.studies,
      'groups': preferences.groups,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
}
