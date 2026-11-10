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

  Future<Map<String, dynamic>> createPost(
    SupabaseClient client,
    String content, {
    String visibility = 'public',
    String? groupId,
    String? roleId,
    bool postedAsGroup = false,
  }) async {
    final row = <String, dynamic>{
      'id': uuidV4(),
      'user_id': client.auth.currentUser!.id,
      'content': content,
      'visibility': visibility,
      'posted_as_group': postedAsGroup,
    };
    if (groupId != null) row['group_id'] = groupId;
    if (roleId != null) row['role_id'] = roleId;
    await client.from('posts').insert(row);
    final res = await client
        .from('posts')
        .select('id, role_id, role_name_snapshot, posted_as_group')
        .eq('id', row['id'] as String)
        .single();
    return res;
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
    'membro publica com cargo; sÃƒÂ³ gestor publica em nome do grupo',
    () async {
      final client = createSupabaseClient()!;
      final ts = DateTime.now().millisecondsSinceEpoch;

      await signInA(client);

      await cleanupZtestGroups(client);
      final groupId = await createGroup(client, 'ztest-posts selo $ts');
      final dono = await findRole(client, groupId, isSystem: true);

      final asGroup = await createPost(
        client,
        'Aviso oficial do grupo.',
        groupId: groupId,
        roleId: dono['id'] as String,
        postedAsGroup: true,
      );
      expect(asGroup['role_name_snapshot'], 'Dono');
      expect(asGroup['posted_as_group'], isTrue);

      final invite = await createInvite(client, groupId);
      await signInB(client);
      await client.rpc(
        'redeem_group_invite',
        params: {'p_token': invite['token']},
      );
      final membro = await findRole(client, groupId, name: 'Membro');

      await expectError(
        () => createPost(
          client,
          'Tentando publicar em nome do grupo.',
          groupId: groupId,
          roleId: membro['id'] as String,
          postedAsGroup: true,
        ),
        'sem_permissao_publicar_em_nome',
      );

      final asMember = await createPost(
        client,
        'Post normal de membro.',
        groupId: groupId,
        roleId: membro['id'] as String,
        postedAsGroup: false,
      );
      expect(asMember['role_name_snapshot'], 'Membro');

      await client.auth.signOut();
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test(
    'cargo de outro grupo ÃƒÂ© bloqueado',
    () async {
      final client = createSupabaseClient()!;
      final ts = DateTime.now().millisecondsSinceEpoch;

      await signInA(client);

      await cleanupZtestGroups(client);
      final g1 = await createGroup(client, 'ztest-posts grupo1 $ts');
      final g2 = await createGroup(client, 'ztest-posts grupo2 $ts');
      final donoG2 = await findRole(client, g2, isSystem: true);

      await expectError(
        () => createPost(
          client,
          'Post no grupo 1 com cargo do grupo 2.',
          groupId: g1,
          roleId: donoG2['id'] as String,
        ),
        'cargo_de_outro_grupo',
      );

      await client.auth.signOut();
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 30)),
  );

  test(
    'selo em post pessoal exige grupo pÃƒÂºblico verificado',
    () async {
      final client = createSupabaseClient()!;
      final ts = DateTime.now().millisecondsSinceEpoch;

      await signInA(client);

      await cleanupZtestGroups(client);
      final privateGroup = await createGroup(client, 'ztest-posts privado selo $ts');
      final dono = await findRole(client, privateGroup, isSystem: true);

      await expectError(
        () => createPost(
          client,
          'Post pessoal com selo de grupo privado.',
          roleId: dono['id'] as String,
        ),
        'selo_exige_grupo_publico',
      );

      await client.auth.signOut();
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 30)),
  );

  test(
    'snapshot permanece quando o cargo ÃƒÂ© removido e apagado',
    () async {
      final client = createSupabaseClient()!;
      final ts = DateTime.now().millisecondsSinceEpoch;

      await signInA(client);

      await cleanupZtestGroups(client);
      final groupId = await createGroup(client, 'ztest-posts snapshot $ts');

      final moderadorId = await client.rpc(
        'create_group_role',
        params: {
          'p_group_id': groupId,
          'p_name': 'Moderador',
          'p_permissions': ['moderate_content'],
        },
      ) as String;

      final invite = await createInvite(client, groupId);
      await signInB(client);
      await client.rpc(
        'redeem_group_invite',
        params: {'p_token': invite['token']},
      );
      final userBId = client.auth.currentUser!.id;

      await signInA(client);
      await client.rpc(
        'assign_group_role',
        params: {
          'p_group_id': groupId,
          'p_user_id': userBId,
          'p_role_id': moderadorId,
        },
      );

      await signInB(client);
      final post = await createPost(
        client,
        'Post com cargo que depois serÃƒÂ¡ removido.',
        groupId: groupId,
        roleId: moderadorId,
      );
      expect(post['role_name_snapshot'], 'Moderador');

      await signInA(client);
      await client.rpc(
        'remove_group_role',
        params: {
          'p_group_id': groupId,
          'p_user_id': userBId,
          'p_role_id': moderadorId,
        },
      );

      await signInB(client);
      final snapshot = await client
          .from('posts')
          .select('role_id, role_name_snapshot')
          .eq('id', post['id'])
          .single();
      expect(snapshot['role_name_snapshot'], 'Moderador');
      expect(snapshot['role_id'], isNotNull);

      await signInA(client);
      await client.rpc('delete_group_role', params: {'p_role_id': moderadorId});

      await signInB(client);
      final afterDelete = await client
          .from('posts')
          .select('role_id, role_name_snapshot')
          .eq('id', post['id'])
          .single();
      expect(afterDelete['role_name_snapshot'], 'Moderador');
      expect(afterDelete['role_id'], isNull);

      await client.auth.signOut();
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
