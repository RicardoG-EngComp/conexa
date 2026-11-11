import 'dart:io';
import 'dart:typed_data';

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

  Future<void> expectThrows(Future<dynamic> Function() action) async {
    try {
      await action();
      fail('esperado erro');
    } catch (_) {}
  }

  test(
    'conta suspensa nao le feed, posts, conversas nem interage',
    () async {
      final client = createSupabaseClient()!;
      final postId = uuidV4();
      final ts = DateTime.now().millisecondsSinceEpoch;

      await signInB(client);
      final userB = client.auth.currentUser!.id;
      await signInA(client);
      final userA = client.auth.currentUser!.id;
      await client.from('posts').insert({
        'id': postId,
        'user_id': userA,
        'content': 'post suspensao $ts',
        'visibility': 'public',
        'posted_as_group': false,
      });

      try {
        await signInAdmin(client);
        await client.rpc(
          'admin_set_account_status',
          params: {'p_user_id': userB, 'p_status': 'suspended'},
        );

        await signInB(client);
        final cvp = await client.rpc(
          'can_view_post',
          params: {'post_id': postId},
        );
        expect(cvp, isFalse);

        final feed = await client.rpc(
          'feed_for_you',
          params: {'p_limit': 30, 'p_offset': 0},
        ) as List;
        expect(feed.isEmpty, isTrue);

        final convs = await client.from('conversations').select('id');
        expect((convs as List).isEmpty, isTrue);

        await expectThrows(
          () => client.from('likes').insert({
            'post_id': postId,
            'user_id': userB,
          }),
        );

        await expectError(
          () => client.from('reports').insert({
            'reporter_id': userB,
            'reported_user_id': userA,
            'target_type': 'post',
            'target_id': postId,
            'category': 'assedio',
          }),
          'conta_inativa',
        );
      } finally {
        await signInAdmin(client);
        await client.rpc(
          'admin_set_account_status',
          params: {'p_user_id': userB, 'p_status': 'active'},
        );
        await signInA(client);
        await client.from('posts').delete().eq('id', postId);
        await client.auth.signOut();
      }
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 150)),
  );

  test(
    'conexao: sem insert direto e sem notificar bloqueado',
    () async {
      final client = createSupabaseClient()!;
      await signInB(client);
      final userB = client.auth.currentUser!.id;
      await signInA(client);
      final userA = client.auth.currentUser!.id;
      await deleteConnectionBetween(client, userA, userB);

      try {
        await client.from('blocks').delete().eq('blocker_id', userA);
        await client.from('blocks').insert({
          'blocker_id': userA,
          'blocked_id': userB,
        });

        await expectError(
          () => client.rpc(
            'send_connection_request',
            params: {'target_user': userB},
          ),
          'blocked',
        );

        await expectThrows(
          () => client.from('connections').insert({
            'requester_id': userA,
            'addressee_id': userB,
            'status': 'pending',
          }),
        );
      } finally {
        await client.from('blocks').delete().eq('blocker_id', userA);
        await deleteConnectionBetween(client, userA, userB);
        await client.auth.signOut();
      }
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 90)),
  );

  test(
    'bloqueio esconde comentarios e curtidas do bloqueado',
    () async {
      final client = createSupabaseClient()!;
      final postId = uuidV4();
      final ts = DateTime.now().millisecondsSinceEpoch;

      await signInB(client);
      final userB = client.auth.currentUser!.id;
      await signInA(client);
      final userA = client.auth.currentUser!.id;
      await client.from('blocks').delete().eq('blocker_id', userA);
      await client.from('posts').insert({
        'id': postId,
        'user_id': userA,
        'content': 'post bloqueio $ts',
        'visibility': 'public',
        'posted_as_group': false,
      });

      try {
        await signInB(client);
        await client.from('comments').insert({
          'id': uuidV4(),
          'post_id': postId,
          'user_id': userB,
          'content': 'comentario do bloqueado',
        });
        await client.from('likes').insert({
          'post_id': postId,
          'user_id': userB,
        });

        await signInA(client);
        final beforeComments = await client
            .from('comments')
            .select('id')
            .eq('post_id', postId);
        final beforeLikes = await client
            .from('likes')
            .select('user_id')
            .eq('post_id', postId);
        expect((beforeComments as List).length, 1);
        expect((beforeLikes as List).length, 1);

        await client.from('blocks').insert({
          'blocker_id': userA,
          'blocked_id': userB,
        });

        final afterComments = await client
            .from('comments')
            .select('id')
            .eq('post_id', postId);
        final afterLikes = await client
            .from('likes')
            .select('user_id')
            .eq('post_id', postId);
        expect((afterComments as List).isEmpty, isTrue);
        expect((afterLikes as List).isEmpty, isTrue);
      } finally {
        await signInA(client);
        await client.from('blocks').delete().eq('blocker_id', userA);
        await client.from('posts').delete().eq('id', postId);
        await client.auth.signOut();
      }
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 120)),
  );

  test(
    'denuncia: alvo precisa ser visivel e created_at e do servidor',
    () async {
      final client = createSupabaseClient()!;
      final friendsPost = uuidV4();
      final publicPost = uuidV4();
      final ts = DateTime.now().millisecondsSinceEpoch;

      await signInB(client);
      final userB = client.auth.currentUser!.id;
      await client.from('posts').insert({
        'id': friendsPost,
        'user_id': userB,
        'content': 'friends denuncia $ts',
        'visibility': 'friends',
        'posted_as_group': false,
      });
      await client.from('posts').insert({
        'id': publicPost,
        'user_id': userB,
        'content': 'publica denuncia $ts',
        'visibility': 'public',
        'posted_as_group': false,
      });

      await signInA(client);
      final userA = client.auth.currentUser!.id;
      await deleteConnectionBetween(client, userA, userB);

      try {
        await expectError(
          () => client.from('reports').insert({
            'reporter_id': userA,
            'reported_user_id': userB,
            'target_type': 'post',
            'target_id': friendsPost,
            'category': 'assedio',
          }),
          'alvo_inacessivel',
        );

        await client.from('reports').insert({
          'reporter_id': userA,
          'reported_user_id': userB,
          'target_type': 'post',
          'target_id': publicPost,
          'category': 'assedio',
          'created_at': '2001-01-01T00:00:00Z',
        });
        final report = await client
            .from('reports')
            .select('created_at')
            .eq('reporter_id', userA)
            .eq('target_id', publicPost)
            .single();
        expect(
          DateTime.parse(report['created_at'] as String).year,
          isNot(2001),
        );
      } finally {
        await signInB(client);
        await client.from('posts').delete().eq('id', friendsPost);
        await client.from('posts').delete().eq('id', publicPost);
        await client.auth.signOut();
      }
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 120)),
  );

  test(
    'avatar e fotos nao podem apontar para arquivo de outro usuario',
    () async {
      final client = createSupabaseClient()!;
      await signInB(client);
      final userB = client.auth.currentUser!.id;
      await signInA(client);
      final userA = client.auth.currentUser!.id;

      final me = await client
          .from('profiles')
          .select('avatar_url, photos')
          .eq('id', userA)
          .single();
      final originalAvatar = me['avatar_url'] as String?;
      final originalPhotos = (me['photos'] as List?) ?? const [];

      try {
        await expectError(
          () => client
              .from('profiles')
              .update({'avatar_url': '$userB/roubado.jpg'})
              .eq('id', userA),
          'caminho_invalido',
        );

        await expectError(
          () => client
              .from('profiles')
              .update({
                'photos': ['$userB/roubada.jpg'],
              })
              .eq('id', userA),
          'caminho_invalido',
        );

        await client
            .from('profiles')
            .update({
              'photos': ['$userA/foto-teste.jpg'],
            })
            .eq('id', userA);
        final own = await client
            .from('profiles')
            .select('photos')
            .eq('id', userA)
            .single();
        expect(
          ((own['photos'] as List).first as String),
          startsWith('$userA/'),
        );
      } finally {
        final safePhotos = originalPhotos
            .whereType<String>()
            .where((p) => p.startsWith('$userA/'))
            .toList();
        final safeAvatar =
            (originalAvatar == null || originalAvatar.startsWith('$userA/'))
            ? originalAvatar
            : null;
        await client
            .from('profiles')
            .update({'avatar_url': safeAvatar, 'photos': safePhotos})
            .eq('id', userA);
        await client.auth.signOut();
      }
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 90)),
  );

  test(
    'storage de verificacao restringe escrita a pasta do dono',
    () async {
      final client = createSupabaseClient()!;
      await signInB(client);
      final userB = client.auth.currentUser!.id;
      await signInA(client);
      final userA = client.auth.currentUser!.id;
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      final ownPath = '$userA/seguranca-teste.jpg';

      try {
        await expectThrows(
          () => client.storage
              .from('verification-docs')
              .uploadBinary(
                '$userB/intruso.jpg',
                bytes,
                fileOptions: const FileOptions(contentType: 'image/jpeg'),
              ),
        );

        await client.storage
            .from('verification-docs')
            .uploadBinary(
              ownPath,
              bytes,
              fileOptions: const FileOptions(contentType: 'image/jpeg'),
            );
        await client.storage.from('verification-docs').remove([ownPath]);
      } finally {
        await client.auth.signOut();
      }
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 90)),
  );
}
