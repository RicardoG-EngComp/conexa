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
        .select('conversation_id, last_read_at')
        .eq('user_id', user.id);
    final convIds = (myRows as List)
        .map((r) => r['conversation_id'] as String)
        .toList();
    if (convIds.isEmpty) return [];

    final lastReadMap = <String, DateTime>{
      for (final r in (myRows as List))
        r['conversation_id'] as String: DateTime.parse(
          r['last_read_at'] as String,
        ).toUtc(),
    };

    final convRows = await _client
        .from('conversations')
        .select('id, status, initiator_id, request_message')
        .inFilter('id', convIds);
    final convInfo = <String, Map<String, dynamic>>{
      for (final r in (convRows as List))
        r['id'] as String: r as Map<String, dynamic>,
    };

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
        .select('conversation_id, sender_id, content, kind, created_at')
        .inFilter('conversation_id', convIds)
        .order('created_at', ascending: false);
    final last = <String, Map<String, dynamic>>{};
    final unread = <String, int>{};
    for (final m in (messages as List)) {
      final map = m as Map<String, dynamic>;
      final cid = map['conversation_id'] as String;
      last.putIfAbsent(cid, () => map);

      if (map['sender_id'] != user.id) {
        final created = DateTime.parse(map['created_at'] as String).toUtc();
        final lastRead =
            lastReadMap[cid] ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
        if (created.isAfter(lastRead)) {
          unread[cid] = (unread[cid] ?? 0) + 1;
        }
      }
    }

    final summaries = convIds.map((cid) {
      final lastMessage = last[cid];
      final otherId = otherUsers[cid] ?? '';
      final info = convInfo[cid];
      final lastKind = (lastMessage?['kind'] as String?) ?? 'text';
      final lastPreview = lastMessage == null
          ? null
          : lastKind == 'sticker'
              ? 'Figurinha'
              : lastKind == 'gif'
                  ? 'GIF'
                  : lastMessage['content'] as String?;
      return ConversationSummary(
        id: cid,
        otherUserId: otherId,
        otherName: names[otherId] ?? 'Estudante UFV',
        status: (info?['status'] as String?) ?? 'accepted',
        initiatorId: info?['initiator_id'] as String?,
        requestMessage: info?['request_message'] as String?,
        lastMessage: lastPreview,
        lastAt: lastMessage == null
            ? null
            : DateTime.parse(lastMessage['created_at'] as String),
        unreadCount: unread[cid] ?? 0,
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
        .order('created_at', ascending: true)
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

  Future<void> markAsRead(String conversationId) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    await _client
        .from('conversation_participants')
        .update({'last_read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('conversation_id', conversationId)
        .eq('user_id', user.id);
  }

  Future<Map<String, dynamic>> sendMessageRequest({
    required String otherUserId,
    required String message,
  }) async {
    final result = await _client.rpc(
      'send_message_request',
      params: {'other_user': otherUserId, 'message': message},
    );
    return (result as Map).cast<String, dynamic>();
  }

  Future<void> acceptRequest(String conversationId) async {
    await _client
        .from('conversations')
        .update({'status': 'accepted'})
        .eq('id', conversationId);
  }

  Future<void> declineRequest(String conversationId) async {
    await _client
        .from('conversations')
        .update({
          'status': 'declined',
          'declined_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', conversationId);
  }
}
