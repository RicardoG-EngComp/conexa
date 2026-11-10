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

  Future<String> createPost(
    SupabaseClient client,
    String content, {
    String visibility = 'public',
    String? quotedPostId,
  }) async {
    final row = <String, dynamic>{
      'id': uuidV4(),
      'user_id': client.auth.currentUser!.id,
      'content': content,
      'visibility': visibility,
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

  Future<String> createComment(
    SupabaseClient client,
    String postId,
    String content, {
    String? parentId,
  }) async {
    final row = <String, dynamic>{
      'id': uuidV4(),
      'post_id': postId,
      'user_id': client.auth.currentUser!.id,
      'content': content,
    };
    if (parentId != null) row['parent_id'] = parentId;
    await client.from('comments').insert(row);
    final res = await client
        .from('comments')
        .select('id')
        .eq('id', row['id'] as String)
        .single();
    return res['id'] as String;
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
    'resposta encadeada respeita o limite de 3 níveis',
    () async {
      final client = createSupabaseClient()!;
      await signInA(client);
      final postId = await createPost(
        client,
        'Post para testar respostas encadeadas.',
      );

      final c0 = await createComment(client, postId, 'ComentÃ¡rio raiz');
      final c1 = await createComment(
        client,
        postId,
        'Resposta nível 1',
        parentId: c0,
      );
      final c2 = await createComment(
        client,
        postId,
        'Resposta nível 2',
        parentId: c1,
      );
      final c3 = await createComment(
        client,
        postId,
        'Resposta nível 3',
        parentId: c2,
      );

      await expectRpcError(
        () =>
            createComment(client, postId, 'Tentativa de nível 4', parentId: c3),
        'profundidade_maxima',
      );

      await client.auth.signOut();
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 30)),
  );

  test(
    'citar publicação inacessível é bloqueado na criação',
    () async {
      final client = createSupabaseClient()!;

      await signInA(client);
      final friendsPost = await createPost(
        client,
        'Post só para conexões.',
        visibility: 'friends',
      );

      await signInB(client);
      await expectRpcError(
        () => createPost(
          client,
          'Tentando citar um post de conexões de outra pessoa.',
          quotedPostId: friendsPost,
        ),
        'publicacao_inacessivel',
      );

      await client.auth.signOut();
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 30)),
  );

  test(
    'citação mantém "foi citação" quando o original é apagado',
    () async {
      final client = createSupabaseClient()!;
      await signInA(client);

      final original = await createPost(client, 'Post original público.');
      final quote = await createPost(
        client,
        'Concordo com o que foi dito.',
        quotedPostId: original,
      );

      final before = await client
          .from('posts')
          .select('quoted_post_id, was_quote')
          .eq('id', quote)
          .single();
      expect(before['was_quote'], isTrue);
      expect(before['quoted_post_id'], original);

      await client.from('posts').delete().eq('id', original);

      final after = await client
          .from('posts')
          .select('quoted_post_id, was_quote')
          .eq('id', quote)
          .single();
      expect(after['was_quote'], isTrue);
      expect(after['quoted_post_id'], isNull);

      await client.auth.signOut();
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
