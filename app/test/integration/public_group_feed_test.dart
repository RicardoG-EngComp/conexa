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
  final emailAdmin = Platform.environment['TEST_ADMIN_EMAIL'] ?? '';
  final passwordAdmin = Platform.environment['TEST_ADMIN_PASSWORD'] ?? '';

  Future<void> signInA(SupabaseClient client) =>
      signInWithRetry(client, emailA, passwordA);
  Future<void> signInB(SupabaseClient client) =>
      signInWithRetry(client, emailB, passwordB);
  Future<void> signInAdmin(SupabaseClient client) =>
      signInWithRetry(client, emailAdmin, passwordAdmin);

  Future<void> cleanupZtestAdm(SupabaseClient client) async {
    final rows = await client
        .from('groups')
        .select('id')
        .like('name', 'ztest-adm%');
    for (final r in (rows as List)) {
      try {
        await client.rpc('delete_group', params: {'p_group_id': r['id']});
      } catch (_) {}
    }
  }

  test(
    'grupo público aprovado aparece no feed e no diretório',
    () async {
      final client = createSupabaseClient()!;
      final ts = DateTime.now().millisecondsSinceEpoch;
      final groupName = 'ztest-adm publico $ts';

      await signInA(client);
      await cleanupZtestAdm(client);
      final res = await client.rpc(
        'create_group',
        params: {'p_name': groupName, 'p_visibility': 'public'},
      );
      final groupId = (res as Map)['id'] as String;
      await client.rpc('request_public_group', params: {'p_group_id': groupId});

      await signInAdmin(client);
      await client.rpc(
        'admin_review_group',
        params: {'p_group_id': groupId, 'p_approve': true},
      );
      await signInA(client);

      final dono =
          (await client
                  .from('group_roles')
                  .select('id')
                  .eq('group_id', groupId)
                  .eq('is_system', true))
              as List;
      final roleId = dono.first['id'] as String;
      final postId = uuidV4();
      await client.from('posts').insert({
        'id': postId,
        'user_id': client.auth.currentUser!.id,
        'content': 'Post publico do grupo aprovado $ts.',
        'visibility': 'public',
        'group_id': groupId,
        'role_id': roleId,
        'posted_as_group': true,
      });

      final topics = (await client.from('topics').select('id, kind').inFilter(
        'label',
        ['Viçosa', 'Acadêmico'],
      )) as List;
      expect(topics.length, 2);
      for (final t in topics) {
        await client.from('post_topics').insert({
          'post_id': postId,
          'topic_id': t['id'] as String,
        });
      }
      final inserted = await client
          .from('post_topics')
          .select('post_id, topic_id')
          .eq('post_id', postId);
      expect((inserted as List).length, 2);

      await signInB(client);
      final meId = client.auth.currentUser!.id;
      await client.from('profiles').update({'campus': 'Viçosa'}).eq('id', meId);
      await client.rpc('follow_group', params: {'p_group_id': groupId});

      final conn = (await client.rpc(
        'feed_connections',
        params: {'p_limit': 30, 'p_offset': 0},
      )) as List;
      final connectionRow = conn.firstWhere(
        (r) => r['post_id'] == postId,
        orElse: () => null,
      );
      expect(connectionRow, isNotNull);
      expect(connectionRow['source'], 'group_followed');

      final forYou = (await client.rpc(
        'feed_for_you',
        params: {'p_limit': 30, 'p_offset': 0},
      )) as List;
      final forYouRow = forYou.firstWhere(
        (r) => r['post_id'] == postId,
        orElse: () => null,
      );
      expect(forYouRow, isNotNull);
      final prefs = await client
          .from('profiles')
          .select('campus')
          .eq('id', client.auth.currentUser!.id)
          .single();
      expect(prefs['campus'], 'Viçosa');
      expect(forYouRow['campus_match'], isTrue);

      final directory = (await client.rpc(
        'public_group_directory',
        params: {'p_search': 'ztest-adm publico $ts'},
      )) as List;
      expect(directory.any((g) => g['id'] == groupId), isTrue);
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 90)),
  );
}
