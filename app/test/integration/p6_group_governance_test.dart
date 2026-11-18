import 'dart:io';

import 'package:conexa/features/groups/data/group_repository.dart';
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
    'P6: gestao transferivel e administradores institucionais',
    () async {
      final client = createSupabaseClient()!;
      final ts = DateTime.now().millisecondsSinceEpoch;
      String? commonGroup;
      String? institutionalGroup;

      await signInB(client);
      final userB = client.auth.currentUser!.id;
      await signInA(client);
      final userA = client.auth.currentUser!.id;
      await deleteConnectionBetween(client, userA, userB);

      try {
        final common = await client.rpc(
          'create_group',
          params: {
            'p_name': 'ztest gov $ts',
            'p_category': 'Outros',
            'p_campus': 'Viçosa',
            'p_visibility': 'private',
          },
        );
        commonGroup = (common as Map)['id'] as String;

        final repo = GroupRepository(client);
        var detail = await repo.fetchGroupDetail(commonGroup);
        expect(detail?.isLeader, isTrue);

        final roles = await repo.fetchRoles(commonGroup);
        final leaderRole = roles.firstWhere((role) => role.isSystem);
        expect(leaderRole.name, 'Dono');

        await inviteUserToGroup(
          client,
          groupId: commonGroup,
          inviterId: userA,
          targetUserId: userB,
          signInInviter: () => signInA(client),
          signInTarget: () => signInB(client),
        );

        await signInA(client);
        await repo.transferLeadership(commonGroup, userB);

        detail = await repo.fetchGroupDetail(commonGroup);
        expect(detail?.isLeader, isFalse);
        expect(detail?.ownerId, userB);

        await signInB(client);
        detail = await repo.fetchGroupDetail(commonGroup);
        expect(detail?.isLeader, isTrue);
        final createdRole = await repo.createRole(
          commonGroup,
          'Coordenação $ts',
          const ['manage_members', 'post_as_group'],
        );
        expect(createdRole, isNotEmpty);

        await signInA(client);
        await expectLater(
          repo.createRole(commonGroup, 'Sem permissão', const []),
          throwsA(anything),
        );

        await signInB(client);
        await repo.removeMember(commonGroup, userA);

        final institutional = await client.rpc(
          'create_group',
          params: {
            'p_name': 'ztest CA $ts',
            'p_category': 'Centro Acadêmico',
            'p_campus': 'Viçosa',
            'p_visibility': 'private',
          },
        );
        institutionalGroup = (institutional as Map)['id'] as String;
        final institutionalRoles = await repo.fetchRoles(institutionalGroup);
        expect(
          institutionalRoles.firstWhere((role) => role.isSystem).name,
          'Administração',
        );

        await inviteUserToGroup(
          client,
          groupId: institutionalGroup,
          inviterId: userB,
          targetUserId: userA,
          signInInviter: () => signInB(client),
          signInTarget: () => signInA(client),
        );

        await signInB(client);
        await repo.addAdministrator(institutionalGroup, userA);
        await repo.removeAdministrator(institutionalGroup, userB);

        await signInA(client);
        detail = await repo.fetchGroupDetail(institutionalGroup);
        expect(detail?.isLeader, isTrue);
        expect(detail?.ownerId, userA);
      } finally {
        await signInA(client);
        if (institutionalGroup != null) {
          try {
            await client.rpc(
              'delete_group',
              params: {'p_group_id': institutionalGroup},
            );
          } catch (_) {}
        }
        await signInB(client);
        if (commonGroup != null) {
          try {
            await client.rpc(
              'delete_group',
              params: {'p_group_id': commonGroup},
            );
          } catch (_) {}
        }
        await deleteConnectionBetween(client, userA, userB);
        await client.auth.signOut();
      }
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 120)),
  );
}
