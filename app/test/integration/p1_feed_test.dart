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
    required String variant,
    required String contentType,
    String? assetId,
  }) async {
    final token = client.auth.currentSession!.accessToken;
    final request = await HttpClient().postUrl(
      Uri.parse('$supabaseUrl/functions/v1/media-upload'),
    );
    request.headers.set('Authorization', 'Bearer $token');
    request.headers.set('apikey', anonKey);
    request.headers.contentType = ContentType.parse(contentType);
    request.headers.set('x-kind', kind);
    request.headers.set('x-variant', variant);
    request.headers.set('x-width', '1');
    request.headers.set('x-height', '1');
    if (assetId != null) request.headers.set('x-asset-id', assetId);
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
    'bookmark, repost, enquete, edicao, fixacao e mencao',
    () async {
      final client = createSupabaseClient()!;
      final postA = uuidV4();
      final postB = uuidV4();
      final repostId = uuidV4();
      final ts = DateTime.now().millisecondsSinceEpoch;

      await signInB(client);
      final userB = client.auth.currentUser!.id;
      await signInA(client);
      final userA = client.auth.currentUser!.id;

      try {
        await client.from('posts').insert({
          'id': postA,
          'user_id': userA,
          'content': 'p1 autor $ts',
          'visibility': 'public',
          'posted_as_group': false,
        });
        await signInB(client);
        await client.from('posts').insert({
          'id': postB,
          'user_id': userB,
          'content': 'p1 original $ts',
          'visibility': 'public',
          'posted_as_group': false,
        });

        await signInA(client);
        final bookmark = await client.rpc(
          'toggle_bookmark',
          params: {'p_post_id': postB},
        );
        expect(bookmark['bookmarked'], isTrue);
        final saved = await client
            .from('post_bookmarks')
            .select('post_id')
            .eq('post_id', postB);
        expect((saved as List).length, 1);

        final edited = await client.rpc(
          'edit_post',
          params: {'p_post_id': postA, 'p_content': 'p1 editado $ts'},
        );
        expect(edited['edited_at'], isNotNull);
        final pinned = await client.rpc(
          'pin_post',
          params: {'p_post_id': postA, 'p_pin': true},
        );
        expect(pinned['pinned'], isTrue);

        await signInB(client);
        await client.from('likes').insert({'post_id': postA, 'user_id': userB});
        await client.from('comments').insert({
          'post_id': postA,
          'user_id': userB,
          'content': 'p1 comentario $ts',
        });
        await signInA(client);
        final interactionNotifications = await client
            .from('notifications')
            .select('type')
            .eq('user_id', userA)
            .inFilter('type', ['like', 'comment']);
        expect(
          (interactionNotifications as List).length,
          greaterThanOrEqualTo(2),
        );

        final poll = await client.rpc(
          'create_poll',
          params: {
            'p_post_id': postA,
            'p_options': ['A', 'B'],
            'p_hours': 24,
          },
        );
        final pollId = poll['poll_id'] as String;
        final option = await client
            .from('poll_options')
            .select('id')
            .eq('poll_id', pollId)
            .eq('position', 0)
            .single();

        await signInB(client);
        await client.rpc(
          'vote_poll',
          params: {'p_poll_id': pollId, 'p_option_id': option['id']},
        );
        final results = await client.rpc(
          'poll_results',
          params: {
            'p_poll_ids': [pollId],
          },
        ) as List;
        expect(results.length, 2);
        expect(
          results.any((r) => r['option_id'] == option['id'] && r['votes'] == 1),
          isTrue,
        );

        await signInA(client);
        await client.rpc(
          'set_post_mentions',
          params: {
            'p_post_id': postA,
            'p_user_ids': [userB],
          },
        );
        await client.from('posts').insert({
          'id': repostId,
          'user_id': userA,
          'content': '',
          'visibility': 'public',
          'posted_as_group': false,
          'repost_of_id': postB,
        });
        final repost = await client
            .from('posts')
            .select('was_repost, content')
            .eq('id', repostId)
            .single();
        expect(repost['was_repost'], isTrue);
        expect(repost['content'], '');

        await signInB(client);
        final notifications = await client
            .from('notifications')
            .select('type')
            .eq('user_id', userB)
            .inFilter('type', ['mention', 'repost', 'like', 'comment']);
        expect((notifications as List).length, greaterThanOrEqualTo(1));
      } finally {
        await signInA(client);
        await client.from('posts').delete().inFilter('id', [
          postA,
          postB,
          repostId,
        ]);
        await client.auth.signOut();
      }
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 200)),
  );

  test(
    'agendamento publica no admin; midia do feed assina para conexao',
    () async {
      final client = createSupabaseClient()!;
      final postId = uuidV4();
      final ts = DateTime.now().millisecondsSinceEpoch;
      String? mediaKey;

      await signInA(client);
      final userA = client.auth.currentUser!.id;
      await signInB(client);
      final userB = client.auth.currentUser!.id;
      final topic = await client
          .from('topics')
          .select('id')
          .eq('is_active', true)
          .limit(1)
          .single();

      try {
        await signInA(client);
        final scheduled = await client.rpc(
          'schedule_post',
          params: {
            'p_payload': {
              'content': 'p1 agendado $ts',
              'visibility': 'public',
              'reply_policy': 'anyone',
              'topic_ids': [topic['id']],
              'mentions': [userB],
            },
            'p_scheduled_at': DateTime.now()
                .add(const Duration(minutes: 10))
                .toUtc()
                .toIso8601String(),
          },
        );
        expect(scheduled['scheduled_at'], isNotNull);
        final rows = await client
            .from('scheduled_posts')
            .select('id, status')
            .eq('status', 'pending');
        expect((rows as List).isNotEmpty, isTrue);
        final scheduledId = rows.first['id'] as String;

        await signInAdmin(client);
        final published = await client.rpc(
          'admin_publish_scheduled_post',
          params: {'p_id': scheduledId},
        );
        expect(
          published['status'],
          'published',
          reason: '${published['error']}',
        );
        final publishedPostId = published['post_id'] as String;

        await signInA(client);
        final publishedPost = await client
            .from('posts')
            .select('content')
            .eq('id', publishedPostId)
            .single();
        expect(publishedPost['content'], 'p1 agendado $ts');
        final topicRows = await client
            .from('post_topics')
            .select('topic_id')
            .eq('post_id', publishedPostId);
        expect((topicRows as List).length, 1);
        final mentionRows = await client
            .from('post_mentions')
            .select('user_id')
            .eq('post_id', publishedPostId);
        expect((mentionRows as List).length, 1);

        await client.from('posts').delete().eq('id', publishedPostId);

        final processed = await ImageProcessor.feedImage(png);
        final (status, uploaded) = await upload(
          client,
          bytes: processed.full,
          kind: 'feed_image',
          variant: 'full',
          contentType: 'image/webp',
        );
        expect(status, 200, reason: uploaded.toString());
        mediaKey = uploaded['key'] as String?;
        expect(mediaKey, isNotNull);
        expect(mediaKey!, startsWith('$userA/feed/'));

        final (thumbStatus, thumbUploaded) = await upload(
          client,
          bytes: processed.thumb,
          kind: 'feed_image',
          variant: 'thumb',
          contentType: 'image/webp',
          assetId: uploaded['assetId'] as String?,
        );
        expect(thumbStatus, 200, reason: thumbUploaded.toString());

        await client.from('posts').insert({
          'id': postId,
          'user_id': userA,
          'content': 'p1 midia $ts',
          'visibility': 'public',
          'posted_as_group': false,
        });
        await client.from('post_media').insert({
          'post_id': postId,
          'owner_id': userA,
          'object_key': mediaKey,
          'kind': 'image',
          'mime_type': 'image/webp',
          'byte_size': processed.full.length,
          'width': processed.width,
          'height': processed.height,
          'alt_text': 'Teste',
          'position': 0,
        });

        await signInB(client);
        final signed = await client.functions.invoke(
          'feed-media-sign',
          body: {
            'paths': [mediaKey],
          },
        );
        final data = signed.data as Map<String, dynamic>;
        final items = data['items'] as Map<String, dynamic>;
        final item = items[mediaKey] as Map<String, dynamic>?;
        expect(item, isNotNull);
        expect(await getStatus(item!['full'] as String), 200);
        expect(await getStatus(item['thumb'] as String), 200);

        await signInA(client);
        await client.functions.invoke(
          'media-delete',
          body: {
            'scope': 'feed',
            'paths': [mediaKey],
          },
        );
        expect(await getStatus(item['full'] as String), 404);
      } finally {
        await signInA(client);
        await client.from('posts').delete().eq('id', postId);
        await client.auth.signOut();
      }
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 200)),
  );
}
