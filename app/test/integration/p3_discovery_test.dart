import 'dart:io';

import 'package:conexa/core/utils/uuid.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'helpers.dart';

void main() {
  final skip = skipIfNoCredentials();

  final emailA = Platform.environment['TEST_USER_A_EMAIL'] ?? '';
  final passwordA = Platform.environment['TEST_USER_A_PASSWORD'] ?? '';
  final emailB = Platform.environment['TEST_USER_B_EMAIL'] ?? '';
  final passwordB = Platform.environment['TEST_USER_B_PASSWORD'] ?? '';

  Future<void> signInA(SupabaseClient c) =>
      signInWithRetry(c, emailA, passwordA);
  Future<void> signInB(SupabaseClient c) =>
      signInWithRetry(c, emailB, passwordB);

  test(
    'P3: busca, feed personalizado, nao interessado e analytics',
    () async {
      final client = createSupabaseClient()!;
      final ts = DateTime.now().millisecondsSinceEpoch;
      final word = 'ztestp3search$ts';
      final postB = uuidV4();
      final postA = uuidV4();
      String? feedId;

      await signInB(client);
      final userB = client.auth.currentUser!.id;
      await signInA(client);
      final userA = client.auth.currentUser!.id;
      final topic = await client
          .from('topics')
          .select('id')
          .eq('is_active', true)
          .limit(1)
          .single();

      try {
        await signInB(client);
        await client.from('posts').insert({
          'id': postB,
          'user_id': userB,
          'content': 'texto $word sobre campus',
          'visibility': 'public',
          'posted_as_group': false,
        });

        await signInA(client);
        await client.from('posts').insert({
          'id': postA,
          'user_id': userA,
          'content': 'post analytics P3 $ts',
          'visibility': 'public',
          'posted_as_group': false,
        });
        await client.from('post_topics').insert({
          'post_id': postA,
          'topic_id': topic['id'],
        });

        final search = await client.rpc(
          'search_posts',
          params: {'p_query': word, 'p_limit': 20, 'p_offset': 0},
        ) as List;
        expect(search.any((r) => r['post_id'] == postB), isTrue);

        final feed = await client.rpc(
          'feed_for_you',
          params: {'p_limit': 100, 'p_offset': 0},
        ) as List;
        expect(feed.any((r) => r['post_id'] == postB), isTrue);

        await client.rpc(
          'set_not_interested',
          params: {'p_post_id': postB, 'p_hidden': true},
        );
        final feedAfter = await client.rpc(
          'feed_for_you',
          params: {'p_limit': 100, 'p_offset': 0},
        ) as List;
        expect(feedAfter.any((r) => r['post_id'] == postB), isFalse);
        final searchAfter = await client.rpc(
          'search_posts',
          params: {'p_query': word, 'p_limit': 20, 'p_offset': 0},
        ) as List;
        expect(searchAfter.any((r) => r['post_id'] == postB), isFalse);

        final custom = await client
            .from('custom_feeds')
            .insert({
              'id': uuidV4(),
              'user_id': userA,
              'name': 'ztest feed $ts',
              'topic_ids': [topic['id']],
            })
            .select('id')
            .single();
        feedId = custom['id'] as String;
        final customFeed = await client.rpc(
          'feed_custom',
          params: {'p_feed_id': feedId, 'p_limit': 50, 'p_offset': 0},
        ) as List;
        expect(customFeed.any((r) => r['post_id'] == postA), isTrue);

        await signInB(client);
        await client.from('likes').insert({'post_id': postA, 'user_id': userB});
        await client.from('comments').insert({
          'post_id': postA,
          'user_id': userB,
          'content': 'analytics P3 $ts',
        });

        await signInA(client);
        final analytics =
            await client.rpc('my_analytics', params: {'p_days': 30}) as Map;
        expect((analytics['posts'] as num).toInt(), greaterThanOrEqualTo(1));
        expect((analytics['likes'] as num).toInt(), greaterThanOrEqualTo(1));
        expect((analytics['comments'] as num).toInt(), greaterThanOrEqualTo(1));
        final top = analytics['top_posts'] as List;
        expect(top.isNotEmpty, isTrue);
      } finally {
        await signInA(client);
        if (feedId != null) {
          await client.from('custom_feeds').delete().eq('id', feedId);
        }
        await client.from('posts').delete().inFilter('id', [postA, postB]);
        await client.auth.signOut();
      }
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 200)),
  );
}
