import 'package:supabase_flutter/supabase_flutter.dart';

import 'chat_models.dart';

class ChatRepository {
  ChatRepository(this._client);

  final SupabaseClient _client;

  Future<String> startConversation(String otherUserId) async {
    final result = await _client.rpc(
      'start_conversation',
      params: {'other_user': otherUserId},
    );
    return result as String;
  }

  Future<List<ConversationSummary>> fetchConversations() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    final myRows = await _client
        .from('conversation_participants')
        .select('conversation_id')
        .eq('user_id', user.id);
    final convIds = (myRows as List)
        .map((r) => r['conversation_id'] as String)
        .toList();
    if (convIds.isEmpty) return [];

    final otherRows = await _client
        .from('conversation_participants')
        .select('conversation_id, user_id')
        .inFilter('conversation_id', convIds)
        .neq('user_id', user.id);
    final otherUsers = <String, String>{
      for (final r in (otherRows as List))
        r['conversation_id'] as String: r['user_id'] as String,
    };

    final userIds = otherUsers.values.toSet().toList();
    final profiles = await _client
        .from('profiles_public')
        .select('id, display_name')
        .inFilter('id', userIds);
    final names = <String, String>{
      for (final p in (profiles as List))
        p['id'] as String: (p['display_name'] as String?) ?? 'Estudante UFV',
    };

    final messages = await _client
        .from('messages')
        .select('conversation_id, content, created_at')
        .inFilter('conversation_id', convIds)
        .order('created_at', ascending: false);
    final last = <String, Map<String, dynamic>>{};
    for (final m in (messages as List)) {
      final map = m as Map<String, dynamic>;
      last.putIfAbsent(map['conversation_id'] as String, () => map);
    }

    final summaries = convIds.map((cid) {
      final lastMessage = last[cid];
      final otherId = otherUsers[cid] ?? '';
      return ConversationSummary(
        id: cid,
        otherUserId: otherId,
        otherName: names[otherId] ?? 'Estudante UFV',
        lastMessage: lastMessage?['content'] as String?,
        lastAt: lastMessage == null
            ? null
            : DateTime.parse(lastMessage['created_at'] as String),
      );
    }).toList();

    summaries.sort((a, b) {
      final da = a.lastAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final db = b.lastAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return db.compareTo(da);
    });
    return summaries;
  }

  Stream<List<ChatMessage>> streamMessages(String conversationId) {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at')
        .map((rows) => rows.map(ChatMessage.fromMap).toList());
  }

  Future<void> sendMessage({
    required String conversationId,
    required String content,
    required bool flagged,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    await _client.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': user.id,
      'content': content.trim(),
      'flagged': flagged,
    });
  }
}
