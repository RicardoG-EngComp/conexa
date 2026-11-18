import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:conexa/core/media/image_processor.dart';
import 'package:conexa/core/utils/uuid.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'helpers.dart';

void main() {
  final skip = skipIfNoCredentials();

  final supabaseUrl = Platform.environment['SUPABASE_URL'] ?? '';
  final anonKey = Platform.environment['SUPABASE_ANON_KEY'] ?? '';
  final emailA = Platform.environment['TEST_USER_A_EMAIL'] ?? '';
  final passwordA = Platform.environment['TEST_USER_A_PASSWORD'] ?? '';
  final emailB = Platform.environment['TEST_USER_B_EMAIL'] ?? '';
  final passwordB = Platform.environment['TEST_USER_B_PASSWORD'] ?? '';

  Future<void> signInA(SupabaseClient c) =>
      signInWithRetry(c, emailA, passwordA);
  Future<void> signInB(SupabaseClient c) =>
      signInWithRetry(c, emailB, passwordB);

  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
    '+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  );

  Future<(int, Map<String, dynamic>)> upload(
    SupabaseClient client, {
    required Uint8List bytes,
    required String kind,
    required String contentType,
  }) async {
    final token = client.auth.currentSession!.accessToken;
    final request = await HttpClient().postUrl(
      Uri.parse('$supabaseUrl/functions/v1/media-upload'),
    );
    request.headers.set('Authorization', 'Bearer $token');
    request.headers.set('apikey', anonKey);
    request.headers.contentType = ContentType.parse(contentType);
    request.headers.set('x-kind', kind);
    request.headers.set('x-variant', 'full');
    request.headers.set('x-width', '1');
    request.headers.set('x-height', '1');
    request.add(bytes);
    final response = await request.close();
    final body = await utf8.decodeStream(response);
    final data = body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(body) as Map<String, dynamic>;
    return (response.statusCode, data);
  }

  Future<int> getStatus(String url) async {
    final response = await (await HttpClient().getUrl(Uri.parse(url))).close();
    await response.drain<void>();
    return response.statusCode;
  }

  Future<void> expectError(
    Future<dynamic> Function() action,
    String fragment,
  ) async {
    try {
      await action();
      fail('esperado erro contendo "$fragment"');
    } catch (e) {
      expect(e.toString(), contains(fragment));
    }
  }

  test(
    'P2: grupo, reply, reacao, edicao, mute, pin/archive, typing e midia',
    () async {
      final client = createSupabaseClient()!;
      final ts = DateTime.now().millisecondsSinceEpoch;
      String? mediaKey;

      await signInB(client);
      final userB = client.auth.currentUser!.id;
      await signInA(client);
      final userA = client.auth.currentUser!.id;

      await deleteConnectionBetween(client, userA, userB);
      await client.rpc(
        'send_connection_request',
        params: {'target_user': userB},
      );
      await signInB(client);
      await client.rpc(
        'respond_connection_request',
        params: {'requester': userA, 'accept': true},
      );
      await signInA(client);

      try {
        final group = await client.rpc(
          'create_group_conversation',
          params: {
            'p_title': 'ztest P2 $ts',
            'p_member_ids': [userB],
          },
        );
        final conversationId = group['conversation_id'] as String;
        expect(group['members'], 2);

        final messageId = uuidV4();
        await client.from('messages').insert({
          'id': messageId,
          'conversation_id': conversationId,
          'sender_id': userA,
          'content': 'mensagem P2 $ts',
          'kind': 'text',
        });
        await client.from('messages').insert({
          'conversation_id': conversationId,
          'sender_id': userA,
          'content': 'segunda mensagem P2 $ts',
          'kind': 'text',
        });

        await signInB(client);
        final senderProfile = await client
            .from('profiles_public')
            .select('display_name')
            .eq('id', userA)
            .single();
        final messageNotification = await client
            .from('notifications')
            .select('title, body, data')
            .eq('user_id', userB)
            .eq('type', 'message')
            .contains('data', {'conversation_id': conversationId})
            .order('created_at', ascending: false)
            .limit(1)
            .single();
        expect(messageNotification['title'], senderProfile['display_name']);
        expect(
          messageNotification['body'],
          contains('2 novas mensagens'),
        );
        expect((messageNotification['data'] as Map)['unread_count'], 2);
        final conversations = await client
            .from('conversations')
            .select('id, kind, title')
            .eq('id', conversationId)
            .single();
        expect(conversations['kind'], 'group');
        expect(conversations['title'], 'ztest P2 $ts');

        final replyId = uuidV4();
        await client.from('messages').insert({
          'id': replyId,
          'conversation_id': conversationId,
          'sender_id': userB,
          'content': 'resposta P2 $ts',
          'kind': 'text',
          'reply_to_id': messageId,
        });

        await client.rpc(
          'toggle_message_reaction',
          params: {'p_message_id': messageId, 'p_emoji': '👍'},
        );
        final reactions = await client
            .from('message_reactions')
            .select('message_id, user_id, emoji')
            .eq('message_id', messageId);
        expect((reactions as List).length, 1);

        await client.rpc(
          'toggle_message_reaction',
          params: {'p_message_id': messageId, 'p_emoji': '👍'},
        );
        final afterReactions = await client
            .from('message_reactions')
            .select('message_id')
            .eq('message_id', messageId);
        expect((afterReactions as List).isEmpty, isTrue);

        await client.rpc(
          'set_conversation_muted',
          params: {'p_conversation_id': conversationId, 'p_muted': true},
        );
        final mutedRow = await client
            .from('conversation_participants')
            .select('muted_until')
            .eq('conversation_id', conversationId)
            .eq('user_id', userB)
            .single();
        expect(mutedRow['muted_until'], isNotNull);

        final beforeMutedNotifications = await client
            .from('notifications')
            .select('id')
            .eq('user_id', userB)
            .eq('type', 'message');
        final beforeCount = (beforeMutedNotifications as List).length;

        await signInA(client);
        await client.from('messages').insert({
          'conversation_id': conversationId,
          'sender_id': userA,
          'content': 'silenciada P2 $ts',
          'kind': 'text',
        });

        await signInB(client);
        final afterMutedNotifications = await client
            .from('notifications')
            .select('id')
            .eq('user_id', userB)
            .eq('type', 'message');
        expect((afterMutedNotifications as List).length, beforeCount);

        await client.rpc(
          'set_conversation_muted',
          params: {'p_conversation_id': conversationId, 'p_muted': false},
        );
        await client.rpc(
          'set_conversation_pinned',
          params: {'p_conversation_id': conversationId, 'p_pin': true},
        );
        await client.rpc(
          'set_conversation_archived',
          params: {'p_conversation_id': conversationId, 'p_archived': true},
        );
        final prefs = await client
            .from('conversation_participants')
            .select('pinned_at, archived_at')
            .eq('conversation_id', conversationId)
            .eq('user_id', userB)
            .single();
        expect(prefs['pinned_at'], isNotNull);
        expect(prefs['archived_at'], isNotNull);
        await client.rpc(
          'set_conversation_archived',
          params: {'p_conversation_id': conversationId, 'p_archived': false},
        );

        await client.from('typing_indicators').upsert({
          'conversation_id': conversationId,
          'user_id': userB,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
        await signInA(client);
        final typing = await client
            .from('typing_indicators')
            .select('user_id')
            .eq('conversation_id', conversationId);
        expect((typing as List).length, 1);
        await signInB(client);
        await client
            .from('typing_indicators')
            .delete()
            .eq('conversation_id', conversationId)
            .eq('user_id', userB);

        await signInA(client);
        await client.rpc(
          'edit_message',
          params: {
            'p_message_id': messageId,
            'p_content': 'mensagem editada P2 $ts',
          },
        );
        final edited = await client
            .from('messages')
            .select('content, edited_at')
            .eq('id', messageId)
            .single();
        expect(edited['content'], 'mensagem editada P2 $ts');
        expect(edited['edited_at'], isNotNull);

        final processed = await ImageProcessor.feedImage(png);
        final (status, uploaded) = await upload(
          client,
          bytes: processed.full,
          kind: 'chat_image',
          contentType: 'image/webp',
        );
        expect(status, 200, reason: uploaded.toString());
        mediaKey = uploaded['key'] as String?;
        expect(mediaKey, startsWith('$userA/chat/'));

        final mediaMessageId = uuidV4();
        await client.from('messages').insert({
          'id': mediaMessageId,
          'conversation_id': conversationId,
          'sender_id': userA,
          'content': '',
          'kind': 'image',
          'media_path': mediaKey,
          'media_mime': 'image/webp',
          'media_bytes': processed.full.length,
          'media_width': processed.width,
          'media_height': processed.height,
          'media_name': 'teste.webp',
        });

        await signInB(client);
        final signed = await client.functions.invoke(
          'chat-media-sign',
          body: {
            'paths': [mediaKey],
          },
        );
        final signedData = signed.data as Map<String, dynamic>;
        final items = signedData['items'] as Map<String, dynamic>;
        final item = items[mediaKey] as Map<String, dynamic>?;
        expect(item, isNotNull);
        expect(await getStatus(item!['full'] as String), 200);

        await signInA(client);
        await client.functions.invoke(
          'media-delete',
          body: {
            'scope': 'chat',
            'paths': [mediaKey],
          },
        );
        expect(await getStatus(item['full'] as String), 404);
        await client.rpc(
          'delete_message_for_everyone',
          params: {'p_message_id': mediaMessageId},
        );

        final direct = await client.rpc(
          'start_conversation',
          params: {'other_user': userB},
        ) as String;
        await expectError(
          () => client.from('messages').insert({
            'conversation_id': direct,
            'sender_id': userA,
            'content': 'reply cross P2 $ts',
            'kind': 'text',
            'reply_to_id': messageId,
          }),
          'mensagem_de_outra_conversa',
        );
      } finally {
        await signInA(client);
        try {
          await deleteConnectionBetween(client, userA, userB);
        } catch (_) {}
        await client.auth.signOut();
      }
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 240)),
  );
}
