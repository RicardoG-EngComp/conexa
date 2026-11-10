import 'package:conexa/core/utils/uuid.dart';

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'helpers.dart';

void main() {
  final skip = skipIfNoCredentials();

  final emailA = Platform.environment['TEST_USER_A_EMAIL'] ?? '';
  final passwordA = Platform.environment['TEST_USER_A_PASSWORD'] ?? '';
  final emailB = Platform.environment['TEST_USER_B_EMAIL'] ?? '';
  final passwordB = Platform.environment['TEST_USER_B_PASSWORD'] ?? '';

  Future<void> signInA(SupabaseClient client) async {
    await signInWithRetry(client, emailA, passwordA);
  }

  Future<void> signInB(SupabaseClient client) async {
    await signInWithRetry(client, emailB, passwordB);
  }

  Future<void> cleanupZtestGroups(SupabaseClient client) async {
    final rows = await client
        .from('groups')
        .select('id')
        .filter('name', 'ilike', 'ztest%');
    for (final r in (rows as List)) {
      try {
        await client.rpc('delete_group', params: {'p_group_id': r['id']});
      } catch (_) {}
    }
  }

  Future<String> createGroup(SupabaseClient client, String name) async {
    final res = await client.rpc(
      'create_group',
      params: {'p_name': name, 'p_visibility': 'private'},
    );
    return (res as Map)['id'] as String;
  }

  Future<Map<String, dynamic>> findRole(
    SupabaseClient client,
    String groupId, {
    String? name,
    bool? isSystem,
  }) async {
    final rows = await client
        .from('group_roles')
        .select('id, name, is_system')
        .eq('group_id', groupId);
    final list = (rows as List).cast<Map<String, dynamic>>();
    return list.firstWhere(
      (r) =>
          (name == null || r['name'] == name) &&
          (isSystem == null || r['is_system'] == isSystem),
    );
  }

  Future<Map<String, dynamic>> createInvite(
    SupabaseClient client,
    String groupId,
  ) async {
    final res = await client.rpc(
      'create_group_invite',
      params: {
        'p_group_id': groupId,
        'p_expires_at': DateTime.now()
            .toUtc()
            .add(const Duration(hours: 1))
            .toIso8601String(),
        'p_max_uses': 1,
      },
    );
    return (res as Map).cast<String, dynamic>();
  }

  Future<String> createGroupPost(
    SupabaseClient client,
    String groupId,
    String roleId, {
    String? quotedPostId,
  }) async {
    final row = <String, dynamic>{
      'id': uuidV4(),
      'user_id': client.auth.currentUser!.id,
      'content': 'Post de grupo de teste.',
      'visibility': 'public',
      'group_id': groupId,
      'role_id': roleId,
    };
    if (quotedPostId != null) row['quoted_post_id'] = quotedPostId;
    await client.from('posts').insert(row);
    final res = await client
        .from('posts')
        .select('id')
        .eq('id', row['id'] as String)
        .single();
    return res['id'] as String;
  }

  Future<String> createComment(SupabaseClient client, String postId) async {
    var id = uuidV4();
    await client.from('comments').insert({
      'id': id,
      'post_id': postId,
      'user_id': client.auth.currentUser!.id,
      'content': 'ComentÃƒÂ¡rio de teste.',
    });
    return id;
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

  Future<void> expectThrows(Future<dynamic> Function() action) async {
    try {
      await action();
      fail('esperado erro');
    } catch (_) {
      // ok
    }
  }

  test(
    'moderador de grupo oculta post e comentÃƒÂ¡rio; nÃƒÂ£o-moderador falha',
    () async {
      final client = createSupabaseClient()!;
      final ts = DateTime.now().millisecondsSinceEpoch;

      await signInA(client);
      await cleanupZtestGroups(client);
      final groupId = await createGroup(client, 'ztest-mod moderacao $ts');
      final dono = await findRole(client, groupId, isSystem: true);

      final postId = await createGroupPost(
        client,
        groupId,
        dono['id'] as String,
      );
      final commentId = await createComment(client, postId);

      final invite = await createInvite(client, groupId);
      await signInB(client);
      await client.rpc(
        'redeem_group_invite',
        params: {'p_token': invite['token']},
      );
      final userBId = client.auth.currentUser!.id;

      await expectError(
        () => client.rpc(
          'group_moderate_post',
          params: {'p_post_id': postId, 'p_action': 'hide'},
        ),
        'forbidden',
      );

      await signInA(client);
      final moderadorId = await client.rpc(
        'create_group_role',
        params: {
          'p_group_id': groupId,
          'p_name': 'Moderador',
          'p_permissions': ['moderate_content'],
        },
      );
      await client.rpc(
        'assign_group_role',
        params: {
          'p_group_id': groupId,
          'p_user_id': userBId,
          'p_role_id': moderadorId,
        },
      );

      await signInB(client);
      await client.rpc(
        'group_moderate_comment',
        params: {'p_comment_id': commentId, 'p_action': 'hide'},
      );

      final commentRows = await client
          .from('comments')
          .select('id')
          .eq('id', commentId);
      expect((commentRows as List).isEmpty, isTrue);

      final postStillVisible = await client
          .from('posts')
          .select('id')
          .eq('id', postId);
      expect((postStillVisible as List).length, 1);

      await client.rpc(
        'group_moderate_post',
        params: {'p_post_id': postId, 'p_action': 'hide'},
      );
      final postHidden = await client
          .from('posts')
          .select('id')
          .eq('id', postId);
      expect((postHidden as List).isEmpty, isTrue);

      await client.auth.signOut();
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test(
    'post de grupo privado nÃƒÂ£o aparece para nÃƒÂ£o membro no feed',
    () async {
      final client = createSupabaseClient()!;
      final ts = DateTime.now().millisecondsSinceEpoch;

      await signInA(client);
      await cleanupZtestGroups(client);
      final groupId = await createGroup(client, 'ztest-mod feed privado $ts');
      final dono = await findRole(client, groupId, isSystem: true);
      final postId = await createGroupPost(
        client,
        groupId,
        dono['id'] as String,
      );

      await signInB(client);
      final feed = await client.rpc(
        'feed_for_you',
        params: {'p_limit': 30, 'p_offset': 0},
      );
      final ids = (feed as List).map((r) => (r as Map)['post_id']).toList();
      expect(ids.contains(postId), isFalse);

      final rows = await client.from('posts').select('id').eq('id', postId);
      expect((rows as List).isEmpty, isTrue);

      await client.auth.signOut();
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 30)),
  );

  test(
    'citaÃƒÂ§ÃƒÂ£o e resposta em post de grupo respeitam o grupo',
    () async {
      final client = createSupabaseClient()!;
      final ts = DateTime.now().millisecondsSinceEpoch;

      await signInA(client);
      await cleanupZtestGroups(client);
      final groupId = await createGroup(client, 'ztest-mod citacao grupo $ts');
      final dono = await findRole(client, groupId, isSystem: true);
      final postId = await createGroupPost(
        client,
        groupId,
        dono['id'] as String,
      );

      final quoteId = await createGroupPost(
        client,
        groupId,
        dono['id'] as String,
        quotedPostId: postId,
      );
      await createComment(client, postId);

      await signInB(client);
      await expectThrows(() => createComment(client, postId));
      final quoteRows = await client
          .from('posts')
          .select('id')
          .eq('id', quoteId);
      expect((quoteRows as List).isEmpty, isTrue);

      await client.auth.signOut();
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 30)),
  );

  test(
    'bloqueio vale em post de grupo',
    () async {
      final client = createSupabaseClient()!;
      final ts = DateTime.now().millisecondsSinceEpoch;

      await signInA(client);
      final userAId = client.auth.currentUser!.id;
      await cleanupZtestGroups(client);
      final groupId = await createGroup(client, 'ztest-mod bloqueio grupo $ts');
      final dono = await findRole(client, groupId, isSystem: true);
      final postId = await createGroupPost(
        client,
        groupId,
        dono['id'] as String,
      );

      final invite = await createInvite(client, groupId);
      await signInB(client);
      await client.rpc(
        'redeem_group_invite',
        params: {'p_token': invite['token']},
      );
      final userBId = client.auth.currentUser!.id;

      final visible = await client.from('posts').select('id').eq('id', postId);
      expect((visible as List).length, 1);

      await signInA(client);
      await client.from('blocks').insert({
        'blocker_id': userAId,
        'blocked_id': userBId,
      });

      await signInB(client);
      final hidden = await client.from('posts').select('id').eq('id', postId);
      expect((hidden as List).isEmpty, isTrue);

      await signInA(client);
      await client
          .from('blocks')
          .delete()
          .eq('blocker_id', userAId)
          .eq('blocked_id', userBId);

      await client.auth.signOut();
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
