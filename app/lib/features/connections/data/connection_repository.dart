import 'package:supabase_flutter/supabase_flutter.dart';

import 'connection_models.dart';

class ConnectionRepository {
  ConnectionRepository(this._client);

  final SupabaseClient _client;

  String? get _me => _client.auth.currentUser?.id;

  Future<ConnectionsData> fetch() async {
    final me = _me;
    if (me == null) {
      return const ConnectionsData(incoming: [], outgoing: [], accepted: []);
    }

    final rows = await _client
        .from('connections')
        .select('requester_id, addressee_id, status')
        .or('requester_id.eq.$me,addressee_id.eq.$me');

    final entries = <ConnectionEntry>[];
    final ids = <String>{};
    for (final r in (rows as List)) {
      final requester = r['requester_id'] as String;
      final addressee = r['addressee_id'] as String;
      final other = requester == me ? addressee : requester;
      ids.add(other);
      entries.add(
        ConnectionEntry(
          userId: other,
          displayName: 'UFV',
          status: r['status'] as String,
          requesterId: requester,
        ),
      );
    }

    if (ids.isEmpty) {
      return const ConnectionsData(incoming: [], outgoing: [], accepted: []);
    }

    final profiles = await _client
        .from('profiles_public')
        .select('id, display_name, avatar_url')
        .inFilter('id', ids.toList());
    final names = <String, String>{
      for (final p in (profiles as List))
        p['id'] as String: (p['display_name'] as String?) ?? 'UFV',
    };
    final avatars = <String, String?>{
      for (final p in (profiles as List))
        p['id'] as String: p['avatar_url'] as String?,
    };

    final result = entries
        .map(
          (e) => ConnectionEntry(
            userId: e.userId,
            displayName: names[e.userId] ?? 'UFV',
            avatarPath: avatars[e.userId],
            status: e.status,
            requesterId: e.requesterId,
          ),
        )
        .toList();

    return ConnectionsData(
      incoming: result
          .where((e) => e.status == 'pending' && e.requesterId != me)
          .toList(),
      outgoing: result
          .where((e) => e.status == 'pending' && e.requesterId == me)
          .toList(),
      accepted: result.where((e) => e.status == 'accepted').toList(),
    );
  }

  Future<ConnectionStatus> statusWith(String targetId) async {
    final me = _me;
    if (me == null) return const ConnectionStatus(status: 'none');

    final rows = await _client
        .from('connections')
        .select('requester_id, addressee_id, status')
        .or(
          'and(requester_id.eq.$me,addressee_id.eq.$targetId),'
          'and(requester_id.eq.$targetId,addressee_id.eq.$me)',
        )
        .limit(1);

    if ((rows as List).isEmpty) return const ConnectionStatus(status: 'none');
    final r = (rows as List).first;
    final status = r['status'] as String;
    final requester = r['requester_id'] as String;
    if (status == 'accepted') {
      return ConnectionStatus(status: 'accepted', requesterId: requester);
    }
    if (status == 'pending') {
      return ConnectionStatus(
        status: requester == me ? 'pending_out' : 'pending_in',
        requesterId: requester,
      );
    }
    return ConnectionStatus(status: 'declined', requesterId: requester);
  }

  Future<String> sendRequest(String targetId) async {
    final result = await _client.rpc(
      'send_connection_request',
      params: {'target_user': targetId},
    );
    return (result as Map)['status'] as String? ?? 'pending';
  }

  Future<String> respond(String requesterId, bool accept) async {
    final result = await _client.rpc(
      'respond_connection_request',
      params: {'requester': requesterId, 'accept': accept},
    );
    return (result as Map)['status'] as String? ??
        (accept ? 'accepted' : 'declined');
  }
}
