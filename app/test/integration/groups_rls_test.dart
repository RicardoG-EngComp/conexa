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

      await signInB(client);
      final userB = client.auth.currentUser!.id;
      await signInA(client);
      final userA = client.auth.currentUser!.id;

      await expectRpcError(
        () => client.rpc(
          'create_group_invite_for_user',
          params: {'p_group_id': groupId, 'p_target_user_id': userB},
        ),
        'sem_conexao',
      );

      await client.rpc(
        'send_connection_request',
        params: {'target_user': userB},
      );
      await signInB(client);
      await client.rpc(
        'respond_connection_request',
        params: {'requester': userA, 'accept': true},
      );

      try {
        await signInA(client);
        final revokedId = await client.rpc(
          'create_group_invite_for_user',
          params: {'p_group_id': groupId, 'p_target_user_id': userB},
        ) as String;
        await client.rpc(
          'revoke_group_invite',
          params: {'p_invite_id': revokedId},
        );

        final soonId = await client.rpc(
          'create_group_invite_for_user',
          params: {
            'p_group_id': groupId,
            'p_target_user_id': userB,
            'p_expires_at': DateTime.now()
                .toUtc()
                .add(const Duration(seconds: 15))
                .toIso8601String(),
          },
        ) as String;

        await signInB(client);
        await Future<void>.delayed(const Duration(seconds: 16));
        await expectRpcError(
          () => client.rpc(
            'accept_group_invite',
            params: {'p_invite_id': revokedId},
          ),
          'convite revogado',
        );
        await expectRpcError(
          () => client.rpc(
            'accept_group_invite',
            params: {'p_invite_id': soonId},
          ),
          'convite expirado',
        );

        await signInA(client);
        final validId = await client.rpc(
          'create_group_invite_for_user',
          params: {'p_group_id': groupId, 'p_target_user_id': userB},
        ) as String;

        await signInB(client);
        final joined = await client.rpc(
          'accept_group_invite',
          params: {'p_invite_id': validId},
        );
        expect(joined, groupId);

        final memberRows = await client
            .from('group_members')
            .select('status')
            .eq('group_id', groupId)
            .eq('user_id', userB);
        expect((memberRows as List).length, 1);
      } finally {
        await signInA(client);
        await deleteConnectionBetween(client, userA, userB);
        try {
          await client.rpc('delete_group', params: {'p_group_id': groupId});
        } catch (_) {}
        await client.auth.signOut();
      }
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

      await signInB(client);
      final userBId = client.auth.currentUser!.id;
      await inviteUserToGroup(
        client,
        groupId: groupId,
        inviterId: userAId,
        targetUserId: userBId,
        signInInviter: () => signInA(client),
        signInTarget: () => signInB(client),
      );
      await signInB(client);

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
