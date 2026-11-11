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

  Future<void> deleteConnection(
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
    } catch (_) {}
  }

  test(
    'perfil: cliente nao altera campos sensiveis',
    () async {
      final client = createSupabaseClient()!;
      await signInA(client);
      final me = client.auth.currentUser!.id;
      final before = await client
          .from('profiles')
          .select(
            'verification_status, account_status, profile_under_review, ufv_email',
          )
          .eq('id', me)
          .single();

      await client
          .from('profiles')
          .update({
            'verification_status': 'pending',
            'account_status': 'banned',
            'profile_under_review': true,
            'ufv_email': 'hack@alunos.ufv.br',
          })
          .eq('id', me);

      final after = await client
          .from('profiles')
          .select(
            'verification_status, account_status, profile_under_review, ufv_email',
          )
          .eq('id', me)
          .single();

      expect(after['verification_status'], before['verification_status']);
      expect(after['account_status'], before['account_status']);
      expect(after['profile_under_review'], before['profile_under_review']);
      expect(after['ufv_email'], before['ufv_email']);
      await client.auth.signOut();
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test(
    'conexao: nao pode inserir accepted direto',
    () async {
      final client = createSupabaseClient()!;
      await signInB(client);
      final userB = client.auth.currentUser!.id;
      await signInA(client);
      final userA = client.auth.currentUser!.id;
      await deleteConnection(client, userA, userB);

      await expectThrows(
        () => client.from('connections').insert({
          'requester_id': userA,
          'addressee_id': userB,
          'status': 'accepted',
        }),
      );

      await client.from('connections').insert({
        'requester_id': userA,
        'addressee_id': userB,
        'status': 'pending',
      });
      await deleteConnection(client, userA, userB);
      await client.auth.signOut();
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test(
    'conversa: start_conversation exige conexao e respeita bloqueio',
    () async {
      final client = createSupabaseClient()!;
      await signInB(client);
      final userB = client.auth.currentUser!.id;
      await client.from('blocks').delete().eq('blocker_id', userB);
      await signInA(client);
      final userA = client.auth.currentUser!.id;
      await client.from('blocks').delete().eq('blocker_id', userA);
      await deleteConnection(client, userA, userB);

      await expectError(
        () => client.rpc('start_conversation', params: {'other_user': userB}),
        'use_message_request',
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

      await signInA(client);
      final convId = await client.rpc(
        'start_conversation',
        params: {'other_user': userB},
      ) as String;
      expect(convId, isNotEmpty);

      await client.from('blocks').insert({
        'blocker_id': userA,
        'blocked_id': userB,
      });
      await expectError(
        () => client.rpc('start_conversation', params: {'other_user': userB}),
        'blocked',
      );
      await client.from('blocks').delete().eq('blocker_id', userA);
      await deleteConnection(client, userA, userB);
      await client.auth.signOut();
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 120)),
  );

  test(
    'bloqueio esconde historico de mensagens',
    () async {
      final client = createSupabaseClient()!;
      await signInB(client);
      final userB = client.auth.currentUser!.id;
      await client.from('blocks').delete().eq('blocker_id', userB);
      await signInA(client);
      final userA = client.auth.currentUser!.id;
      await client.from('blocks').delete().eq('blocker_id', userA);
      await deleteConnection(client, userA, userB);

      try {
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
        final convId = await client.rpc(
          'start_conversation',
          params: {'other_user': userB},
        ) as String;
        await client.from('messages').insert({
          'conversation_id': convId,
          'sender_id': userA,
          'content': 'mensagem de teste',
        });

        await signInB(client);
        final before = await client
            .from('messages')
            .select('id')
            .eq('conversation_id', convId);
        expect((before as List).isNotEmpty, isTrue);

        await signInA(client);
        await client.from('blocks').insert({
          'blocker_id': userA,
          'blocked_id': userB,
        });

        await signInB(client);
        final after = await client
            .from('messages')
            .select('id')
            .eq('conversation_id', convId);
        expect((after as List).isEmpty, isTrue);
      } finally {
        await signInA(client);
        await client.from('blocks').delete().eq('blocker_id', userA);
        await deleteConnection(client, userA, userB);
        await client.auth.signOut();
      }
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 120)),
  );

  test(
    'denuncias: alvo real, sem duplicata e sem auto-hide com 2 denunciantes',
    () async {
      final client = createSupabaseClient()!;
      final ts = DateTime.now().millisecondsSinceEpoch;
      final postId = uuidV4();

      await signInB(client);
      final userB = client.auth.currentUser!.id;
      await client.from('posts').insert({
        'id': postId,
        'user_id': userB,
        'content': 'post para denuncia $ts',
        'visibility': 'public',
        'posted_as_group': false,
      });

      await signInA(client);
      final userA = client.auth.currentUser!.id;

      await expectError(
        () => client.from('reports').insert({
          'reporter_id': userA,
          'reported_user_id': userA,
          'target_type': 'post',
          'target_id': postId,
          'category': 'violencia_ameaca',
        }),
        'alvo_invalido',
      );

      await client.from('reports').insert({
        'reporter_id': userA,
        'reported_user_id': userB,
        'target_type': 'post',
        'target_id': postId,
        'category': 'violencia_ameaca',
      });

      await expectThrows(
        () => client.from('reports').insert({
          'reporter_id': userA,
          'reported_user_id': userB,
          'target_type': 'post',
          'target_id': postId,
          'category': 'assedio',
        }),
      );

      await signInAdmin(client);
      await client.from('reports').insert({
        'reporter_id': client.auth.currentUser!.id,
        'reported_user_id': userB,
        'target_type': 'post',
        'target_id': postId,
        'category': 'violencia_ameaca',
      });

      await signInB(client);
      final post = await client
          .from('posts')
          .select('id, hidden_at')
          .eq('id', postId);
      expect((post as List).length, 1);
      expect(post.first['hidden_at'], isNull);

      await client.from('posts').delete().eq('id', postId);
      await client.auth.signOut();
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 120)),
  );

  test(
    'superficies legadas de convite e auditoria negadas',
    () async {
      final client = createSupabaseClient()!;
      await signInA(client);
      await expectThrows(
        () => client.rpc(
          'create_group_invite',
          params: {
            'p_group_id': '00000000-0000-0000-0000-000000000000',
            'p_expires_at': DateTime.now().toUtc().toIso8601String(),
            'p_max_uses': 1,
          },
        ),
      );
      await expectThrows(
        () => client.rpc('redeem_group_invite', params: {'p_token': 'x'}),
      );
      await expectThrows(
        () => client.rpc(
          'group_audit',
          params: {
            'g': '00000000-0000-0000-0000-000000000000',
            'a': 'fake',
            't': 'groups',
            'tid': '00000000-0000-0000-0000-000000000000',
            'meta': <String, dynamic>{},
          },
        ),
      );
      await client.auth.signOut();
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test(
    'cargo nao concede permissao que o criador nao tem',
    () async {
      final client = createSupabaseClient()!;
      final ts = DateTime.now().millisecondsSinceEpoch;

      await signInB(client);
      final userB = client.auth.currentUser!.id;
      await signInA(client);
      final userA = client.auth.currentUser!.id;
      await cleanupGroups(client);
      await deleteConnection(client, userA, userB);

      try {
        final res = await client.rpc(
          'create_group',
          params: {
            'p_name': 'ztest-sec cargos $ts',
            'p_visibility': 'private',
            'p_category': 'República',
          },
        );
        final groupId = (res as Map)['id'] as String;

        final gerenteId = await client.rpc(
          'create_group_role',
          params: {
            'p_group_id': groupId,
            'p_name': 'Gerente',
            'p_permissions': ['manage_roles', 'manage_invites'],
          },
        ) as String;

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
        final inviteId = await client.rpc(
          'create_group_invite_for_user',
          params: {'p_group_id': groupId, 'p_target_user_id': userB},
        ) as String;
        await signInB(client);
        await client.rpc(
          'accept_group_invite',
          params: {'p_invite_id': inviteId},
        );
        await signInA(client);
        await client.rpc(
          'assign_group_role',
          params: {
            'p_group_id': groupId,
            'p_user_id': userB,
            'p_role_id': gerenteId,
          },
        );

        await signInB(client);
        await expectError(
          () => client.rpc(
            'create_group_role',
            params: {
              'p_group_id': groupId,
              'p_name': 'Super',
              'p_permissions': ['manage_group'],
            },
          ),
          'permissao_nao_permitida',
        );
        final ok = await client.rpc(
          'create_group_role',
          params: {
            'p_group_id': groupId,
            'p_name': 'Convidante',
            'p_permissions': ['manage_invites'],
          },
        );
        expect(ok, isNotNull);
      } finally {
        await signInA(client);
        await cleanupGroups(client);
        await deleteConnection(client, userA, userB);
        await client.auth.signOut();
      }
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 150)),
  );

  test(
    'created_at do cliente e substituido pelo servidor',
    () async {
      final client = createSupabaseClient()!;
      final postId = uuidV4();
      await signInA(client);
      await client.from('posts').insert({
        'id': postId,
        'user_id': client.auth.currentUser!.id,
        'content': 'post com data forjada',
        'visibility': 'public',
        'posted_as_group': false,
        'created_at': '2035-01-01T00:00:00Z',
      });
      final row = await client
          .from('posts')
          .select('created_at')
          .eq('id', postId)
          .single();
      final year = DateTime.parse(row['created_at'] as String).year;
      expect(year, isNot(2035));
      await client.from('posts').delete().eq('id', postId);
      await client.auth.signOut();
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test(
    'perfil em revisao some do feed e da leitura de post',
    () async {
      final client = createSupabaseClient()!;
      final postId = uuidV4();
      final ts = DateTime.now().millisecondsSinceEpoch;

      await signInB(client);
      final userB = client.auth.currentUser!.id;
      await client.from('blocks').delete().eq('blocker_id', userB);
      await client
          .from('profiles')
          .update({'profile_private': false})
          .eq('id', userB);
      await client.from('posts').insert({
        'id': postId,
        'user_id': userB,
        'content': 'post revisao $ts',
        'visibility': 'public',
        'posted_as_group': false,
      });

      try {
        await signInA(client);
        await client
            .from('blocks')
            .delete()
            .eq('blocker_id', client.auth.currentUser!.id);
        final before = await client.rpc(
          'feed_for_you',
          params: {'p_limit': 200, 'p_offset': 0},
        ) as List;
        expect(before.any((r) => r['post_id'] == postId), isTrue);

        await signInAdmin(client);
        await client.rpc(
          'admin_set_profile_review',
          params: {'p_user_id': userB, 'p_under_review': true},
        );

        await signInA(client);
        final visible = await client
            .from('posts')
            .select('id')
            .eq('id', postId);
        expect((visible as List).isEmpty, isTrue);

        final after = await client.rpc(
          'feed_for_you',
          params: {'p_limit': 200, 'p_offset': 0},
        ) as List;
        expect(after.any((r) => r['post_id'] == postId), isFalse);
      } finally {
        await signInAdmin(client);
        await client.rpc(
          'admin_set_profile_review',
          params: {'p_user_id': userB, 'p_under_review': false},
        );
        await signInB(client);
        await client.from('posts').delete().eq('id', postId);
        await client.auth.signOut();
      }
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 120)),
  );

  test(
    'group_stats nao vaza grupo privado para nao membro',
    () async {
      final client = createSupabaseClient()!;
      final ts = DateTime.now().millisecondsSinceEpoch;

      await signInA(client);
      await cleanupGroups(client);
      final res = await client.rpc(
        'create_group',
        params: {
          'p_name': 'ztest-sec stats $ts',
          'p_visibility': 'private',
          'p_category': 'Outros',
        },
      );
      final groupId = (res as Map)['id'] as String;

      try {
        final own = await client.rpc(
          'group_stats',
          params: {'p_group_id': groupId},
        ) as List;
        expect(own.length, 1);

        await signInB(client);
        final other = await client.rpc(
          'group_stats',
          params: {'p_group_id': groupId},
        ) as List;
        expect(other.isEmpty, isTrue);
      } finally {
        await signInA(client);
        await cleanupGroups(client);
        await client.auth.signOut();
      }
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 90)),
  );
}
