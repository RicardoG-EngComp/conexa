import 'dart:convert';
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
    'mute esconde comentario do autor silenciado',
    () async {
      final client = createSupabaseClient()!;
      final postId = uuidV4();
      final commentId = uuidV4();
      final ts = DateTime.now().millisecondsSinceEpoch;

      await signInB(client);
      final userB = client.auth.currentUser!.id;
      await signInA(client);
      final userA = client.auth.currentUser!.id;

      try {
        await client.rpc('unmute_user', params: {'p_target': userB});
        await client.from('posts').insert({
          'id': postId,
          'user_id': userA,
          'content': 'post mute $ts',
          'visibility': 'public',
          'posted_as_group': false,
        });

        await signInB(client);
        await client.from('comments').insert({
          'id': commentId,
          'post_id': postId,
          'user_id': userB,
          'content': 'comentario mute $ts',
        });

        await signInA(client);
        final before = await client
            .from('comments')
            .select('id')
            .eq('post_id', postId);
        expect((before as List).any((r) => r['id'] == commentId), isTrue);

        await client.rpc('mute_user', params: {'p_target': userB});
        final after = await client
            .from('comments')
            .select('id')
            .eq('post_id', postId);
        expect((after as List).any((r) => r['id'] == commentId), isFalse);
      } finally {
        await signInA(client);
        try {
          await client.rpc('unmute_user', params: {'p_target': userB});
        } catch (_) {}
        await client.from('posts').delete().eq('id', postId);
        await client.auth.signOut();
      }
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 150)),
  );

  test(
    'palavra silenciada esconde post do feed',
    () async {
      final client = createSupabaseClient()!;
      final postId = uuidV4();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final word = 'ztestmute$ts';

      await signInB(client);
      final userB = client.auth.currentUser!.id;
      await signInA(client);

      try {
        await client.rpc('unmute_user', params: {'p_target': userB});

        await signInB(client);
        await client.from('posts').insert({
          'id': postId,
          'user_id': userB,
          'content': 'post com $word para teste',
          'visibility': 'public',
          'posted_as_group': false,
        });

        await signInA(client);
        final before = await client.rpc(
          'feed_for_you',
          params: {'p_limit': 100, 'p_offset': 0},
        ) as List;
        expect(before.any((r) => r['post_id'] == postId), isTrue);

        await client.rpc('add_muted_word', params: {'p_word': word});
        final after = await client.rpc(
          'feed_for_you',
          params: {'p_limit': 100, 'p_offset': 0},
        ) as List;
        expect(after.any((r) => r['post_id'] == postId), isFalse);
      } finally {
        await signInA(client);
        try {
          await client.rpc('remove_muted_word', params: {'p_word': word});
        } catch (_) {}
        await client.from('posts').delete().eq('id', postId);
        await client.auth.signOut();
      }
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 150)),
  );

  test(
    'reply_policy connections bloqueia estranho e libera autor',
    () async {
      final client = createSupabaseClient()!;
      final postId = uuidV4();
      final ts = DateTime.now().millisecondsSinceEpoch;

      await signInB(client);
      final userB = client.auth.currentUser!.id;
      await signInA(client);
      final userA = client.auth.currentUser!.id;
      await deleteConnectionBetween(client, userA, userB);

      try {
        await client.from('posts').insert({
          'id': postId,
          'user_id': userA,
          'content': 'post restrito $ts',
          'visibility': 'public',
          'reply_policy': 'connections',
          'posted_as_group': false,
        });

        await signInB(client);
        await expectError(
          () => client.from('comments').insert({
            'post_id': postId,
            'user_id': userB,
            'content': 'resposta de estranho $ts',
          }),
          'respostas_restritas',
        );

        await signInA(client);
        await client.from('comments').insert({
          'post_id': postId,
          'user_id': userA,
          'content': 'resposta do autor $ts',
        });
      } finally {
        await signInA(client);
        await client.from('posts').delete().eq('id', postId);
        await client.auth.signOut();
      }
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 150)),
  );

  test(
    'export_my_data retorna dados do titular sem cpf_hash',
    () async {
      final client = createSupabaseClient()!;
      final postId = uuidV4();
      final ts = DateTime.now().millisecondsSinceEpoch;

      await signInA(client);
      try {
        await client.from('posts').insert({
          'id': postId,
          'user_id': client.auth.currentUser!.id,
          'content': 'post export $ts',
          'visibility': 'public',
          'posted_as_group': false,
        });

        final data = await client.rpc('export_my_data');
        final encoded = jsonEncode(data);
        expect(encoded.contains('cpf_hash'), isFalse);
        expect(encoded.contains('post export $ts'), isTrue);
        expect(data['profile'], isNotNull);
      } finally {
        await client.from('posts').delete().eq('id', postId);
        await client.auth.signOut();
      }
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 150)),
  );

  test(
    'apelacao de denuncia encerrada e resolvida pelo admin',
    () async {
      final client = createSupabaseClient()!;
      final postId = uuidV4();
      final ts = DateTime.now().millisecondsSinceEpoch;

      await signInB(client);
      final userB = client.auth.currentUser!.id;
      await signInA(client);
      final userA = client.auth.currentUser!.id;
      await signInAdmin(client);
      await ageOutTestReports(client, [userA, userB]);

      try {
        await signInB(client);
        await client.from('posts').insert({
          'id': postId,
          'user_id': userB,
          'content': 'post apelacao $ts',
          'visibility': 'public',
          'posted_as_group': false,
        });

        await signInA(client);
        await client.from('reports').insert({
          'reporter_id': userA,
          'reported_user_id': userB,
          'target_type': 'post',
          'target_id': postId,
          'category': 'assedio',
        });
        final report = await client
            .from('reports')
            .select('id')
            .eq('reporter_id', userA)
            .eq('target_id', postId)
            .single();

        await signInAdmin(client);
        await client
            .from('reports')
            .update({
              'status': 'dismissed',
              'reviewed_at': DateTime.now().toUtc().toIso8601String(),
              'action_taken': 'dismiss',
            })
            .eq('id', report['id']);

        await signInA(client);
        await client.rpc(
          'submit_report_appeal',
          params: {
            'p_report_id': report['id'],
            'p_reason': 'A decisao precisa ser revista para teste.',
          },
        );
        final appealed = await client
            .from('reports')
            .select('appeal_status')
            .eq('id', report['id'])
            .single();
        expect(appealed['appeal_status'], 'pending');

        await signInAdmin(client);
        await client.rpc(
          'admin_resolve_report_appeal',
          params: {
            'p_report_id': report['id'],
            'p_accept': true,
            'p_result': 'Aceita no teste.',
          },
        );

        await signInA(client);
        final resolved = await client
            .from('reports')
            .select('appeal_status')
            .eq('id', report['id'])
            .single();
        expect(resolved['appeal_status'], 'accepted');
      } finally {
        await signInA(client);
        await client.from('posts').delete().eq('id', postId);
        await signInAdmin(client);
        await ageOutTestReports(client, [userA, userB]);
        await client.auth.signOut();
      }
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 200)),
  );

  test(
    'registro de dispositivo e idempotente',
    () async {
      final client = createSupabaseClient()!;
      final deviceId = 'test-device-${DateTime.now().millisecondsSinceEpoch}';
      await signInA(client);
      try {
        final first = await client.rpc(
          'register_device_session',
          params: {
            'p_device_id': deviceId,
            'p_label': 'Teste',
            'p_platform': 'android',
          },
        );
        expect(first['is_new'], isTrue);

        final second = await client.rpc(
          'register_device_session',
          params: {
            'p_device_id': deviceId,
            'p_label': 'Teste',
            'p_platform': 'android',
          },
        );
        expect(second['is_new'], isFalse);
      } finally {
        try {
          await client.rpc(
            'delete_my_device',
            params: {'p_device_id': deviceId},
          );
        } catch (_) {}
        await client.auth.signOut();
      }
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 150)),
  );
}
