import 'package:supabase_flutter/supabase_flutter.dart';

class BlockRepository {
  BlockRepository(this._client);

  final SupabaseClient _client;

  Future<void> block(String targetId) async {
    final me = _client.auth.currentUser?.id;
    if (me == null) return;
    await _client.from('blocks').insert({
      'blocker_id': me,
      'blocked_id': targetId,
    });
  }

  Future<void> unblock(String targetId) async {
    final me = _client.auth.currentUser?.id;
    if (me == null) return;
    await _client
        .from('blocks')
        .delete()
        .eq('blocker_id', me)
        .eq('blocked_id', targetId);
  }

  Future<List<Map<String, dynamic>>> listBlocked() async {
    final rows = await _client.rpc('list_blocked');
    return (rows as List).cast<Map<String, dynamic>>();
  }
}
