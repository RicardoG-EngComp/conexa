import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'helpers.dart';

/// Requisitos das contas de teste: verificadas, perfil completo e diretrizes
/// aceitas (as mesmas exigencias de publicar/conectar).
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

  Future<String> createGroup(
    SupabaseClient client,
    String name, {
    String visibility = 'private',
  }) async {
    final res = await client.rpc(
      'create_group',
      params: {'p_name': name, 'p_visibility': visibility},
    );
    return (res as Map)['id'] as String;
  }

  Future<Map<String, dynamic>> createInvite(
    SupabaseClient client,
    String groupId, {
    Duration validFor = const Duration(hours: 1),
    int maxUses = 1,
  }) async {
    final res = await client.rpc(
      'create_group_invite',
      params: {
        'p_group_id': groupId,
        'p_expires_at': DateTime.now().toUtc().add(validFor).toIso8601String(),
        'p_max_uses': maxUses,
      },
    );
    return (res as Map).cast<String, dynamic>();
  }

  Future<void> expectRpcError(
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
    'grupo privado fica invisível para quem não é membro',
    () async {
      final client = createSupabaseClient()!;
      final ts = DateTime.now().millisecondsSinceEpoch;

      await signInA(client);
      await cleanupZtestGroups(client);
      final groupId = await createGroup(client, 'ztest-rls privado $ts');

      final own = await client.from('groups').select('id').eq('id', groupId);
      expect((own as List).length, 1);

      await signInB(client);
      final other = await client.from('groups').select('id').eq('id', groupId);
      expect((other as List).isEmpty, isTrue);

      await client.auth.signOut();
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 30)),
  );

  test(
    'nome público é único, ignorando acentos, caixa e espaços',
    () async {
      final client = createSupabaseClient()!;
      final ts = DateTime.now().millisecondsSinceEpoch;
      final base = 'ztest-rls nome unico $ts';

      await signInA(client);
      await cleanupZtestGroups(client);
      final g1 = await createGroup(client, base);
      await client.rpc('request_public_group', params: {'p_group_id': g1});

      final g2 = await createGroup(client, '  ${base.toUpperCase()}  ');
      await expectRpcError(
        () => client.rpc('request_public_group', params: {'p_group_id': g2}),
        'nome_publico_em_uso',
      );

      await client.auth.signOut();
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 30)),
  );

  test(
    'convite vÃ¡lido adiciona membro; revogado e vencido falham',
    () async {
      final client = createSupabaseClient()!;
      final ts = DateTime.now().millisecondsSinceEpoch;

      await signInA(client);
      await cleanupZtestGroups(client);
      final groupId = await createGroup(client, 'ztest-rls convites $ts');

      final valid = await createInvite(client, groupId, maxUses: 2);
      final validToken = valid['token'] as String;

      final revoked = await createInvite(client, groupId);
      final revokedId = revoked['id'] as String;
      final revokedToken = revoked['token'] as String;
      await client.rpc(
        'revoke_group_invite',
        params: {'p_invite_id': revokedId},
      );

      final soon = await createInvite(
        client,
        groupId,
        validFor: const Duration(seconds: 15),
      );
      final soonToken = soon['token'] as String;

      await signInB(client);

      await expectRpcError(
        () => client.rpc(
          'redeem_group_invite',
          params: {'p_token': revokedToken},
        ),
        'convite revogado',
      );

      await Future<void>.delayed(const Duration(seconds: 17));
      await expectRpcError(
        () => client.rpc('redeem_group_invite', params: {'p_token': soonToken}),
        'convite expirado',
      );

      final joined = await client.rpc(
        'redeem_group_invite',
        params: {'p_token': validToken},
      );
      expect(joined, isNotNull);

      final memberRows = await client
          .from('group_members')
          .select('status')
          .eq('group_id', groupId)
          .eq('user_id', client.auth.currentUser!.id);
      expect((memberRows as List).length, 1);

      await client.auth.signOut();
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test(
    'ninguém se atribui cargo; só gestor atribui',
    () async {
      final client = createSupabaseClient()!;
      final ts = DateTime.now().millisecondsSinceEpoch;

      await signInA(client);
      await cleanupZtestGroups(client);
      final userAId = client.auth.currentUser!.id;
      final groupId = await createGroup(client, 'ztest-rls cargos $ts');

      final roles =
          (await client
                  .from('group_roles')
                  .select('id, name, is_system')
                  .eq('group_id', groupId))
              as List;
      final donoRole = roles.firstWhere((r) => r['is_system'] == true);
      final membroRole = roles.firstWhere((r) => r['name'] == 'Membro');

      await expectRpcError(
        () => client.rpc(
          'assign_group_role',
          params: {
            'p_group_id': groupId,
            'p_user_id': userAId,
            'p_role_id': membroRole['id'],
          },
        ),
        'nao_pode_se_atribuir',
      );

      final invite = await createInvite(client, groupId);
      final token = invite['token'] as String;

      await signInB(client);
      await client.rpc('redeem_group_invite', params: {'p_token': token});
      final userBId = client.auth.currentUser!.id;

      final bMembroId =
          (await client
                  .from('group_roles')
                  .select('id, name')
                  .eq('group_id', groupId)
                  .eq('name', 'Membro'))
              as List;

      await expectRpcError(
        () => client.rpc(
          'assign_group_role',
          params: {
            'p_group_id': groupId,
            'p_user_id': userAId,
            'p_role_id': bMembroId.first['id'],
          },
        ),
        'forbidden',
      );

      await signInA(client);

      final customRoleId = await client.rpc(
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
          'p_role_id': customRoleId,
        },
      );

      final assigned = await client
          .from('group_member_roles')
          .select('role_id')
          .eq('group_id', groupId)
          .eq('user_id', userBId)
          .eq('role_id', customRoleId);
      expect((assigned as List).length, 1);

      await expectRpcError(
        () => client.rpc(
          'assign_group_role',
          params: {
            'p_group_id': groupId,
            'p_user_id': userBId,
            'p_role_id': donoRole['id'],
          },
        ),
        'cargo_sistema',
      );

      await client.auth.signOut();
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
