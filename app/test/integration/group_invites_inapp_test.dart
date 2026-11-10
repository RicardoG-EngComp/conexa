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
  final emailAdmin = Platform.environment['TEST_ADMIN_EMAIL'] ?? '';
  final passwordAdmin = Platform.environment['TEST_ADMIN_PASSWORD'] ?? '';

  Future<void> signInA(SupabaseClient c) =>
      signInWithRetry(c, emailA, passwordA);
  Future<void> signInB(SupabaseClient c) =>
      signInWithRetry(c, emailB, passwordB);
  Future<void> signInAdmin(SupabaseClient c) =>
      signInWithRetry(c, emailAdmin, passwordAdmin);

  Future<void> cleanupGroups(SupabaseClient client) async {
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

  Future<void> cleanupConnection(
    SupabaseClient client,
    String a,
    String b,
  ) async {
    try {
      await client
          .from('connections')
          .delete()
          .or(
            'and(requester_id.eq.$a,addressee_id.eq.$b),'
            'and(requester_id.eq.$b,addressee_id.eq.$a)',
          );
    } catch (_) {}
  }

  Future<void> connect(SupabaseClient client, String a, String b) async {
    await signInA(client);
    await client.rpc('send_connection_request', params: {'target_user': b});
    await signInB(client);
    await client.rpc(
      'respond_connection_request',
      params: {'requester': a, 'accept': true},
    );
  }

  test(
    'convite direcionado: notificação, aceite e recusa sem link',
    () async {
      final client = createSupabaseClient()!;
      final ts = DateTime.now().millisecondsSinceEpoch;

      await signInA(client);
      final userA = client.auth.currentUser!.id;
      await cleanupGroups(client);
      await signInB(client);
      final userB = client.auth.currentUser!.id;
      await cleanupConnection(client, userA, userB);

      try {
        await connect(client, userA, userB);

        await signInA(client);
        final res = await client.rpc(
          'create_group',
          params: {
            'p_name': 'ztest-inv convite $ts',
            'p_visibility': 'private',
            'p_category': 'República',
          },
        );
        final groupId = (res as Map)['id'] as String;

        final inviteId = await client.rpc(
          'create_group_invite_for_user',
          params: {'p_group_id': groupId, 'p_target_user_id': userB},
        ) as String;
        expect(inviteId, isNotEmpty);

        await signInB(client);
        final pending = await client.rpc('my_group_invites') as List;
        expect(pending.any((i) => i['invite_id'] == inviteId), isTrue);

        final acceptedGroup = await client.rpc(
          'accept_group_invite',
          params: {'p_invite_id': inviteId},
        );
        expect(acceptedGroup, groupId);

        final member = await client
            .from('group_members')
            .select('status')
            .eq('group_id', groupId)
            .eq('user_id', userB)
            .single();
        expect(member['status'], 'active');

        // Segundo convite: recusar.
        await signInA(client);
        final res2 = await client.rpc(
          'create_group',
          params: {
            'p_name': 'ztest-inv recusa $ts',
            'p_visibility': 'private',
            'p_category': 'Outros',
          },
        );
        final groupId2 = (res2 as Map)['id'] as String;
        final inviteId2 = await client.rpc(
          'create_group_invite_for_user',
          params: {'p_group_id': groupId2, 'p_target_user_id': userB},
        ) as String;

        await signInB(client);
        await client.rpc(
          'decline_group_invite',
          params: {'p_invite_id': inviteId2},
        );
        final afterDecline = await client.rpc('my_group_invites') as List;
        expect(afterDecline.any((i) => i['invite_id'] == inviteId2), isFalse);

        // Sem conexão: convite falha.
        await signInA(client);
        await cleanupConnection(client, userA, userB);
        try {
          await client.rpc(
            'create_group_invite_for_user',
            params: {'p_group_id': groupId2, 'p_target_user_id': userB},
          );
          fail('esperado erro sem_conexao');
        } catch (e) {
          expect(e.toString(), contains('sem_conexao'));
        }
      } finally {
        await signInA(client);
        await cleanupGroups(client);
        await cleanupConnection(client, userA, userB);
        await client.auth.signOut();
      }
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 150)),
  );

  test(
    'gestor remove seguidor do grupo',
    () async {
      final client = createSupabaseClient()!;
      final ts = DateTime.now().millisecondsSinceEpoch;

      await signInA(client);
      await cleanupGroups(client);

      try {
        final res = await client.rpc(
          'create_group',
          params: {
            'p_name': 'ztest-inv seguidor $ts',
            'p_visibility': 'public',
            'p_category': 'Centro Acadêmico',
          },
        );
        final groupId = (res as Map)['id'] as String;
        await client.rpc(
          'request_public_group',
          params: {'p_group_id': groupId},
        );

        await signInAdmin(client);
        await client.rpc(
          'admin_review_group',
          params: {'p_group_id': groupId, 'p_approve': true},
        );

        await signInB(client);
        await client.rpc('follow_group', params: {'p_group_id': groupId});
        final stats = await client.rpc(
          'group_stats',
          params: {'p_group_id': groupId},
        ) as List;
        expect((stats.first as Map)['follower_count'], 1);

        await signInA(client);
        final userB =
            (await client
                    .from('group_followers')
                    .select('user_id')
                    .eq('group_id', groupId)
                    .single())['user_id']
                as String;
        expect(userB, isNotEmpty);
        await client.rpc(
          'remove_group_follower',
          params: {'p_group_id': groupId, 'p_user_id': userB},
        );
        final statsAfter = await client.rpc(
          'group_stats',
          params: {'p_group_id': groupId},
        ) as List;
        expect((statsAfter.first as Map)['follower_count'], 0);
      } finally {
        await signInA(client);
        await cleanupGroups(client);
        await client.auth.signOut();
      }
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 120)),
  );
}
