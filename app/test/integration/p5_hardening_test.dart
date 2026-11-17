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
  final emailAdmin = Platform.environment['TEST_ADMIN_EMAIL'] ?? '';
  final passwordAdmin = Platform.environment['TEST_ADMIN_PASSWORD'] ?? '';

  Future<void> signInA(SupabaseClient c) =>
      signInWithRetry(c, emailA, passwordA);
  Future<void> signInB(SupabaseClient c) =>
      signInWithRetry(c, emailB, passwordB);
  Future<void> signInAdmin(SupabaseClient c) =>
      signInWithRetry(c, emailAdmin, passwordAdmin);

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

  test(
    'P5: termos, busca em comentario, views e comentario em avaliacao',
    () async {
      final client = createSupabaseClient()!;
      final ts = DateTime.now().millisecondsSinceEpoch;
      final badTerm = 'ztestbad$ts';
      final postId = uuidV4();
      final commentText = 'ztestcommentbody$ts';
      String? materialId;

      await signInB(client);
      final userB = client.auth.currentUser!.id;
      await signInA(client);
      final userA = client.auth.currentUser!.id;

      try {
        await signInAdmin(client);
        final term = await client
            .from('moderation_terms')
            .insert({
              'term': badTerm,
              'normalized_term': badTerm,
              'category': 'assedio',
              'active': true,
            })
            .select('id')
            .single();
        final termId = term['id'] as String;

        await signInA(client);
        try {
          await client.from('posts').insert({
            'user_id': userA,
            'content': 'texto $badTerm aqui',
            'visibility': 'public',
            'posted_as_group': false,
          });
          fail('esperado bloqueio de termo');
        } catch (e) {
          expect(e.toString(), contains('conteudo_proibido'));
        }

        await signInAdmin(client);
        await client.from('moderation_terms').delete().eq('id', termId);

        await signInA(client);
        await client.from('posts').insert({
          'id': postId,
          'user_id': userA,
          'content': 'post comentario P5 $ts',
          'visibility': 'public',
          'posted_as_group': false,
        });

        await signInB(client);
        await client.from('comments').insert({
          'post_id': postId,
          'user_id': userB,
          'content': commentText,
        });

        await signInA(client);
        final found = await client.rpc(
          'search_comments',
          params: {'p_query': commentText, 'p_limit': 20, 'p_offset': 0},
        ) as List;
        expect(found.any((r) => r['post_id'] == postId), isTrue);

        await client.rpc('record_post_view', params: {'p_post_id': postId});
        await client.rpc('record_post_view', params: {'p_post_id': postId});
        final views =
            await client.rpc('my_views_summary', params: {'p_days': 30}) as Map;
        expect((views['views'] as num).toInt(), greaterThanOrEqualTo(1));

        await signInAdmin(client);
        await client.rpc('admin_grant_uploader', params: {'p_email': emailA});
        await signInA(client);
        materialId = uuidV4();
        final discipline = await client
            .from('disciplines')
            .select('id')
            .limit(1)
            .single();
        await client.from('study_materials').insert({
          'id': materialId,
          'discipline_id': discipline['id'],
          'author_id': userA,
          'title': 'Material P5 $ts',
          'description': 'teste',
          'kind': 'link',
          'external_url': 'https://example.com/p5-$ts',
          'status': 'pending',
          'consent_version': 'test',
        });
        await signInAdmin(client);
        await client.rpc(
          'admin_review_material',
          params: {
            'p_material_id': materialId,
            'p_approve': true,
            'p_note': 'teste',
          },
        );

        await signInA(client);
        await client.rpc(
          'rate_study_material',
          params: {
            'p_material_id': materialId,
            'p_rating': 5,
            'p_comment': 'Comentario P5 $ts',
          },
        );

        await signInB(client);
        final reviews = await client.rpc(
          'study_material_reviews',
          params: {'p_material_id': materialId},
        ) as List;
        expect(
          reviews.any(
            (r) => (r['comment'] as String?)?.contains('P5 $ts') == true,
          ),
          isTrue,
        );
      } finally {
        await signInA(client);
        await client.from('posts').delete().eq('id', postId);
        if (materialId != null) {
          await signInAdmin(client);
          try {
            await client.rpc(
              'admin_moderate_content',
              params: {
                'p_target_type': 'material',
                'p_target_id': materialId,
                'p_action': 'delete',
              },
            );
          } catch (_) {}
        }
        await client.auth.signOut();
      }
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 300)),
  );

  test(
    'P5: midia agendada, anexo Q&A e video bloqueado',
    () async {
      final client = createSupabaseClient()!;
      final ts = DateTime.now().millisecondsSinceEpoch;
      String? postId;
      String? questionId;
      String? mediaKey;
      String? qaKey;

      await signInA(client);
      final userA = client.auth.currentUser!.id;

      try {
        final processed = await ImageProcessor.feedImage(png);
        final (status, uploaded) = await upload(
          client,
          bytes: processed.full,
          kind: 'feed_image',
          contentType: 'image/webp',
        );
        expect(status, 200, reason: uploaded.toString());
        mediaKey = uploaded['key'] as String?;
        expect(mediaKey, isNotNull);

        final scheduled = await client.rpc(
          'schedule_post',
          params: {
            'p_payload': {
              'content': 'post agendado com midia P5 $ts',
              'visibility': 'public',
              'reply_policy': 'anyone',
              'topic_ids': <String>[],
              'mentions': <String>[],
              'media': [
                {
                  'path': mediaKey,
                  'kind': 'image',
                  'mime_type': 'image/webp',
                  'byte_size': processed.full.length,
                  'width': processed.width,
                  'height': processed.height,
                  'position': 0,
                },
              ],
            },
            'p_scheduled_at': DateTime.now()
                .add(const Duration(minutes: 10))
                .toUtc()
                .toIso8601String(),
          },
        );
        expect(scheduled['scheduled_at'], isNotNull);
        final row = await client
            .from('scheduled_posts')
            .select('id')
            .eq('user_id', userA)
            .eq('status', 'pending')
            .order('created_at', ascending: false)
            .limit(1)
            .single();
        await signInAdmin(client);
        final published = await client.rpc(
          'admin_publish_scheduled_post',
          params: {'p_id': row['id']},
        );
        expect(
          published['status'],
          'published',
          reason: '${published['error']}',
        );
        postId = published['post_id'] as String;

        await signInA(client);
        final mediaRows = await client
            .from('post_media')
            .select('object_key')
            .eq('post_id', postId);
        expect((mediaRows as List).length, 1);

        final qa = await ImageProcessor.studyImage(png);
        final (qaStatus, qaUploaded) = await upload(
          client,
          bytes: qa.full,
          kind: 'qa_image',
          contentType: 'image/webp',
        );
        expect(qaStatus, 200, reason: qaUploaded.toString());
        qaKey = qaUploaded['key'] as String?;

        final discipline = await client
            .from('disciplines')
            .select('id')
            .limit(1)
            .single();
        final question = await client
            .from('study_questions')
            .insert({
              'id': uuidV4(),
              'discipline_id': discipline['id'],
              'author_id': userA,
              'title': 'Pergunta P5 midia $ts',
              'content': 'Como anexar imagem P5 $ts?',
              'status': 'open',
            })
            .select('id')
            .single();
        questionId = question['id'] as String;
        await client.from('study_question_attachments').insert({
          'question_id': questionId,
          'owner_id': userA,
          'object_key': qaKey,
          'kind': 'image',
          'mime_type': 'image/webp',
          'byte_size': qa.full.length,
          'name': 'qa.webp',
        });

        final signed = await client.functions.invoke(
          'qa-media-sign',
          body: {
            'paths': [qaKey],
          },
        );
        final data = signed.data as Map<String, dynamic>;
        final items = data['items'] as Map<String, dynamic>;
        final item = items[qaKey] as Map<String, dynamic>?;
        expect(item, isNotNull);
        expect(await getStatus(item!['full'] as String), 200);

        final (videoStatus, videoData) = await upload(
          client,
          bytes: png,
          kind: 'feed_video',
          contentType: 'video/mp4',
        );
        expect(videoStatus, 403);
        expect(videoData['error'], 'video_indisponivel');
      } finally {
        await signInA(client);
        if (postId != null) {
          await client.from('posts').delete().eq('id', postId);
        }
        if (questionId != null) {
          try {
            await client.rpc(
              'delete_study_question',
              params: {'p_question_id': questionId},
            );
          } catch (_) {}
        }
        for (final key in [mediaKey, qaKey].whereType<String>()) {
          try {
            await client.functions.invoke(
              'media-delete',
              body: {
                'scope': key.contains('/qa/') ? 'qa' : 'feed',
                'paths': [key],
              },
            );
          } catch (_) {}
        }
        await client.auth.signOut();
      }
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 300)),
  );

  test(
    'P5: membros do chat, RSVP e busca de Q&A',
    () async {
      final client = createSupabaseClient()!;
      final ts = DateTime.now().millisecondsSinceEpoch;
      String? groupId;
      String? chatId;
      String? questionId;

      await signInB(client);
      final userB = client.auth.currentUser!.id;
      await signInA(client);
      final userA = client.auth.currentUser!.id;
      await deleteConnectionBetween(client, userA, userB);

      try {
        final group = await client.rpc(
          'create_group',
          params: {
            'p_name': 'ztest P5 $ts',
            'p_description': 'grupo P5',
            'p_category': 'outros',
            'p_campus': 'Viçosa',
            'p_visibility': 'private',
          },
        );
        groupId = (group as Map)['id'] as String;

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

        final chat = await client.rpc(
          'create_group_conversation',
          params: {
            'p_title': 'ztest chat P5 $ts',
            'p_member_ids': [userB],
          },
        );
        chatId = chat['conversation_id'] as String;

        await client.rpc(
          'remove_conversation_member',
          params: {'p_conversation_id': chatId, 'p_user_id': userB},
        );
        await signInB(client);
        final removedMessages = await client
            .from('messages')
            .select('id')
            .eq('conversation_id', chatId);
        expect((removedMessages as List).isEmpty, isTrue);

        await signInA(client);
        await client.rpc(
          'add_conversation_members',
          params: {
            'p_conversation_id': chatId,
            'p_user_ids': [userB],
          },
        );

        await client.rpc(
          'create_group_event',
          params: {
            'p_group_id': groupId,
            'p_title': 'Evento P5 $ts',
            'p_description': 'teste',
            'p_starts_at': DateTime.now()
                .add(const Duration(days: 2))
                .toUtc()
                .toIso8601String(),
            'p_ends_at': DateTime.now()
                .add(const Duration(days: 2, hours: 2))
                .toUtc()
                .toIso8601String(),
            'p_location': 'UFV',
          },
        );

        await inviteUserToGroup(
          client,
          groupId: groupId,
          inviterId: userA,
          targetUserId: userB,
          signInInviter: () => signInA(client),
          signInTarget: () => signInB(client),
        );

        await signInB(client);
        final event = await client
            .from('group_events')
            .select('id')
            .eq('group_id', groupId)
            .single();
        await client.rpc(
          'set_event_rsvp',
          params: {'p_event_id': event['id'], 'p_status': 'going'},
        );
        final rsvp = await client
            .from('group_event_rsvps')
            .select('status')
            .eq('event_id', event['id'])
            .eq('user_id', userB)
            .single();
        expect(rsvp['status'], 'going');

        final discipline = await client
            .from('disciplines')
            .select('id')
            .limit(1)
            .single();
        await signInA(client);
        final question = await client
            .from('study_questions')
            .insert({
              'id': uuidV4(),
              'discipline_id': discipline['id'],
              'author_id': userA,
              'title': 'Busca P5 $ts',
              'content': 'Conteudo ztestqa$ts para busca',
              'status': 'open',
            })
            .select('id')
            .single();
        questionId = question['id'] as String;
        final found = await client.rpc(
          'search_study_qa',
          params: {
            'p_discipline_id': discipline['id'],
            'p_query': 'ztestqa$ts',
            'p_limit': 20,
            'p_offset': 0,
          },
        ) as List;
        expect(found.any((r) => r['question_id'] == questionId), isTrue);
      } finally {
        await signInA(client);
        if (questionId != null) {
          try {
            await client.rpc(
              'delete_study_question',
              params: {'p_question_id': questionId},
            );
          } catch (_) {}
        }
        if (groupId != null) {
          try {
            await client.rpc('delete_group', params: {'p_group_id': groupId});
          } catch (_) {}
        }
        try {
          await deleteConnectionBetween(client, userA, userB);
        } catch (_) {}
        await client.auth.signOut();
      }
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 300)),
  );
}
