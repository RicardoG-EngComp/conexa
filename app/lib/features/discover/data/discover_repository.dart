import 'package:supabase_flutter/supabase_flutter.dart';

import 'discover_models.dart';

class DiscoverRepository {
  DiscoverRepository(this._client);

  final SupabaseClient _client;

  Future<List<DiscoverProfile>> fetch({
    required int limit,
    required int offset,
    String? course,
    String? search,
  }) async {
    final rows = await _client.rpc(
      'discover_profiles',
      params: {
        'p_limit': limit,
        'p_offset': offset,
        'p_course': course,
        'p_search': (search == null || search.trim().isEmpty)
            ? null
            : search.trim(),
      },
    );
    return (rows as List)
        .map((r) => DiscoverProfile.fromMap(r as Map<String, dynamic>))
        .toList();
  }
}
