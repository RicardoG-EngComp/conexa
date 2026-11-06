import 'package:supabase_flutter/supabase_flutter.dart';

import 'badge_models.dart';

class BadgeRepository {
  BadgeRepository(this._client);

  final SupabaseClient _client;

  Future<List<ProfileBadge>> fetchForUser(String userId) async {
    final rows = await _client
        .from('user_badges')
        .select('badges(id, slug, name, description, icon, color)')
        .eq('user_id', userId);

    return (rows as List)
        .map((row) {
          final badge = row['badges'];
          if (badge is! Map<String, dynamic>) return null;
          return ProfileBadge.fromMap(badge);
        })
        .whereType<ProfileBadge>()
        .toList();
  }

  Future<int> grantBadges({
    required List<String> emails,
    required String slug,
  }) async {
    final result = await _client.rpc(
      'admin_grant_badges',
      params: {
        'p_emails': emails,
        'p_slug': slug,
      },
    );
    return (result as num?)?.toInt() ?? 0;
  }
}
