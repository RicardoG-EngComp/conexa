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

  Future<String> createGroupConversation(
    String title,
    List<String> memberIds,
  ) async {
    final result = await _client.rpc(
      'create_group_conversation',
      params: {'p_title': title, 'p_member_ids': memberIds},
    );
    return (result as Map)['conversation_id'] as String;
  }

  Future<List<ConversationSummary>> fetchConversations() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    final myRows = await _client
        .from('conversation_participants')
        .select(
          'conversation_id, last_read_at, hidden_at, pinned_at, muted_until, '
          'archived_at, role',
        )
        .eq('user_id', user.id);
    final convIds = (myRows as List)
        .map((r) => r['conversation_id'] as String)
        .toList();
    if (convIds.isEmpty) return [];

    final lastReadMap = <String, DateTime>{};
    final hiddenMap = <String, DateTime>{};
    final pinned = <String>{};
    final muted = <String>{};
    final archived = <String>{};
    for (final r in (myRows as List)) {
      final cid = r['conversation_id'] as String;
      lastReadMap[cid] = DateTime.parse(r['last_read_at'] as String).toUtc();
      if (r['hidden_at'] != null) {
        hiddenMap[cid] = DateTime.parse(r['hidden_at'] as String).toUtc();
      }
      if (r['pinned_at'] != null) pinned.add(cid);
      final mutedUntil = r['muted_until'] == null
          ? null
          : DateTime.parse(r['muted_until'] as String).toUtc();
      if (mutedUntil != null && mutedUntil.isAfter(DateTime.now().toUtc())) {
        muted.add(cid);
      }
      if (r['archived_at'] != null) archived.add(cid);
    }

    final convRows = await _client
        .from('conversations')
        .select(
          'id, kind, title, owner_id, status, initiator_id, request_message, '
          'updated_at',
        )
        .inFilter('id', convIds);
    final convInfo = <String, Map<String, dynamic>>{
      for (final r in (convRows as List))
        r['id'] as String: r as Map<String, dynamic>,
    };

    final participantRows = await _client
        .from('conversation_participants')
        .select('conversation_id, user_id, role')
        .inFilter('conversation_id', convIds);
    final participantsByConv = <String, List<Map<String, dynamic>>>{};
    final userIds = <String>{};
    for (final r in (participantRows as List)) {
      final map = r as Map<String, dynamic>;
      final cid = map['conversation_id'] as String;
      participantsByConv.putIfAbsent(cid, () => []).add(map);
      userIds.add(map['user_id'] as String);
    }

    final profiles = await _client
        .from('profiles_public')
        .select('id, display_name')
        .inFilter('id', userIds.toList());
    final names = <String, String>{
      for (final p in (profiles as List))
        p['id'] as String: (p['display_name'] as String?) ?? 'Estudante UFV',
    };

    final messages = await _client
        .from('messages')
        .select(
          'conversation_id, sender_id, content, kind, media_name, created_at, '
          'deleted_for_all_at',
        )
        .inFilter('conversation_id', convIds)
        .order('created_at', ascending: false);
    final last = <String, Map<String, dynamic>>{};
    final unread = <String, int>{};
    for (final m in (messages as List)) {
      final map = m as Map<String, dynamic>;
      final cid = map['conversation_id'] as String;
      last.putIfAbsent(cid, () => map);

      if (map['sender_id'] != user.id && map['deleted_for_all_at'] == null) {
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
      final info = convInfo[cid];
      final participants = participantsByConv[cid] ?? const [];
      String? otherId;
      for (final p in participants) {
        final id = p['user_id'] as String;
        if (id != user.id) {
          otherId = id;
          break;
        }
      }
      final kind = info?['kind'] as String?;
      final isGroup = kind == 'group' || kind == 'group_chat';
      final memberNames = isGroup
          ? participants
                .map((p) => names[p['user_id'] as String] ?? 'Estudante UFV')
                .where((name) => name.isNotEmpty)
                .toList()
          : const <String>[];
      final lastKind = (lastMessage?['kind'] as String?) ?? 'text';
      final deleted = lastMessage?['deleted_for_all_at'] != null;
      final lastPreview = lastMessage == null
          ? null
          : deleted
          ? 'Mensagem apagada'
          : _preview(lastKind, lastMessage);

      return ConversationSummary(
        id: cid,
        otherUserId: otherId ?? '',
        otherName: names[otherId] ?? 'Estudante UFV',
        status: (info?['status'] as String?) ?? 'accepted',
        initiatorId: info?['initiator_id'] as String?,
        requestMessage: info?['request_message'] as String?,
        lastMessage: lastPreview,
        lastAt: lastMessage == null
            ? null
            : DateTime.parse(lastMessage['created_at'] as String),
        unreadCount: unread[cid] ?? 0,
        isGroup: isGroup,
        title: info?['title'] as String?,
        memberCount: participants.isEmpty ? 2 : participants.length,
        pinned: pinned.contains(cid),
        muted: muted.contains(cid),
        archived: archived.contains(cid),
        memberNames: memberNames,
      );
    }).toList();

    summaries.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      final da = a.lastAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final db = b.lastAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return db.compareTo(da);
    });

    return summaries.where((summary) {
      final hiddenAt = hiddenMap[summary.id];
      if (hiddenAt == null) return true;
      final lastAt = summary.lastAt;
      return lastAt != null && lastAt.toUtc().isAfter(hiddenAt);
    }).toList();
  }

  Future<List<ChatMember>> fetchMembers(String conversationId) async {
    final rows = await _client
        .from('conversation_participants')
        .select('user_id, role')
        .eq('conversation_id', conversationId);
    final ids = (rows as List).map((r) => r['user_id'] as String).toList();
    if (ids.isEmpty) return [];
    final profiles = await _client
        .from('profiles_public')
        .select('id, display_name')
        .inFilter('id', ids);
    final names = <String, String>{
      for (final p in (profiles as List))
        p['id'] as String: (p['display_name'] as String?) ?? 'Estudante UFV',
    };
    return (rows)
        .map(
          (r) => ChatMember(
            userId: r['user_id'] as String,
            displayName: names[r['user_id'] as String] ?? 'Estudante UFV',
            role: (r['role'] as String?) ?? 'member',
          ),
        )
        .toList();
  }

  Stream<List<ChatMessage>> streamMessages(String conversationId) {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true)
        .map((rows) => rows.map(ChatMessage.fromMap).toList());
  }

  Stream<List<MessageReaction>> streamReactions(String conversationId) {
    return _client
        .from('message_reactions')
        .stream(primaryKey: ['message_id', 'user_id'])
        .eq('conversation_id', conversationId)
        .map((rows) => rows.map(MessageReaction.fromMap).toList());
  }

  Stream<List<Map<String, dynamic>>> streamTyping(String conversationId) {
    return _client
        .from('typing_indicators')
        .stream(primaryKey: ['conversation_id', 'user_id'])
        .eq('conversation_id', conversationId);
  }

  Future<void> sendMessage({
    required String conversationId,
    required String content,
    required bool flagged,
    String kind = 'text',
    String? replyToId,
    String? mediaPath,
    String? mediaMime,
    int? mediaBytes,
    int? mediaWidth,
    int? mediaHeight,
    int? mediaDurationMs,
    String? mediaName,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    await _client.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': user.id,
      'content': content.trim(),
      'flagged': flagged,
      'kind': kind,
      'reply_to_id': ?replyToId,
      'media_path': ?mediaPath,
      'media_mime': ?mediaMime,
      'media_bytes': ?mediaBytes,
      'media_width': ?mediaWidth,
      'media_height': ?mediaHeight,
      'media_duration_ms': ?mediaDurationMs,
      'media_name': ?mediaName,
    });
  }

  Future<void> editMessage(String messageId, String content) async {
    await _client.rpc(
      'edit_message',
      params: {'p_message_id': messageId, 'p_content': content},
    );
  }

  Future<bool> toggleReaction(String messageId, String emoji) async {
    final result = await _client.rpc(
      'toggle_message_reaction',
      params: {'p_message_id': messageId, 'p_emoji': emoji},
    );
    return result is Map && result['reacted'] == true;
  }

  Future<void> setTyping(String conversationId, bool typing) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    if (!typing) {
      await _client
          .from('typing_indicators')
          .delete()
          .eq('conversation_id', conversationId)
          .eq('user_id', user.id);
      return;
    }
    await _client.from('typing_indicators').upsert({
      'conversation_id': conversationId,
      'user_id': user.id,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> markAsRead(String conversationId) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    await _client.rpc(
      'mark_conversation_read',
      params: {'p_conversation_id': conversationId},
    );
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

  Future<void> clearConversation(String conversationId) async {
    await _client.rpc(
      'clear_conversation',
      params: {'p_conversation_id': conversationId},
    );
  }

  Future<void> deleteConversation(String conversationId) async {
    await _client.rpc(
      'delete_conversation',
      params: {'p_conversation_id': conversationId},
    );
  }

  Future<void> deleteMessageForMe(String messageId) async {
    await _client.rpc(
      'delete_message_for_me',
      params: {'p_message_id': messageId},
    );
  }

  Future<void> deleteMessageForEveryone(String messageId) async {
    await _client.rpc(
      'delete_message_for_everyone',
      params: {'p_message_id': messageId},
    );
  }

  Future<void> acceptRequest(String conversationId) async {
    await _client.rpc(
      'respond_message_request',
      params: {'p_conversation_id': conversationId, 'p_accept': true},
    );
  }

  Future<void> declineRequest(String conversationId) async {
    await _client.rpc(
      'respond_message_request',
      params: {'p_conversation_id': conversationId, 'p_accept': false},
    );
  }

  Future<void> setPinned(String conversationId, bool pin) async {
    await _client.rpc(
      'set_conversation_pinned',
      params: {'p_conversation_id': conversationId, 'p_pin': pin},
    );
  }

  Future<void> setMuted(String conversationId, bool muted) async {
    await _client.rpc(
      'set_conversation_muted',
      params: {'p_conversation_id': conversationId, 'p_muted': muted},
    );
  }

  Future<void> setArchived(String conversationId, bool archived) async {
    await _client.rpc(
      'set_conversation_archived',
      params: {'p_conversation_id': conversationId, 'p_archived': archived},
    );
  }

  Future<void> addMembers(String conversationId, List<String> userIds) async {
    await _client.rpc(
      'add_conversation_members',
      params: {'p_conversation_id': conversationId, 'p_user_ids': userIds},
    );
  }

  Future<void> removeMember(String conversationId, String userId) async {
    await _client.rpc(
      'remove_conversation_member',
      params: {'p_conversation_id': conversationId, 'p_user_id': userId},
    );
  }

  String _preview(String kind, Map<String, dynamic> message) {
    return switch (kind) {
      'sticker' => 'Figurinha',
      'gif' => 'GIF',
      'image' => 'Imagem',
      'video' => 'Video',
      'file' => (message['media_name'] as String?) ?? 'Arquivo',
      _ => (message['content'] as String?) ?? '',
    };
  }
}
