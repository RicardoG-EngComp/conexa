import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'helpers.dart';

void main() {
  final skip = skipIfNoCredentials();

  final emailA = Platform.environment['TEST_USER_A_EMAIL'] ?? '';
  final passwordA = Platform.environment['TEST_USER_A_PASSWORD'] ?? '';

  Future<void> signInA(SupabaseClient client) =>
      signInWithRetry(client, emailA, passwordA);

  Future<void> cleanup(SupabaseClient client) async {
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
    'categorias de grupo aceitam apenas a lista oficial',
    () async {
      final client = createSupabaseClient()!;
      final ts = DateTime.now().millisecondsSinceEpoch;

      await signInA(client);
      await cleanup(client);

      final res = await client.rpc(
        'create_group',
        params: {
          'p_name': 'ztest-cat atletica $ts',
          'p_visibility': 'private',
          'p_category': 'Atlética',
        },
      );
      final groupId = (res as Map)['id'] as String;
      final stored = await client
          .from('groups')
          .select('category')
          .eq('id', groupId)
          .single();
      expect(stored['category'], 'Atlética');

      await expectError(
        () => client.rpc(
          'create_group',
          params: {
            'p_name': 'ztest-cat invalida $ts',
            'p_visibility': 'private',
            'p_category': 'Categoria Inventada',
          },
        ),
        'categoria_invalida',
      );

      await expectError(
        () => client.rpc(
          'update_group',
          params: {
            'p_group_id': groupId,
            'p_name': 'ztest-cat atletica $ts',
            'p_category': 'Coletivo',
          },
        ),
        'categoria_invalida',
      );

      await client.rpc(
        'update_group',
        params: {
          'p_group_id': groupId,
          'p_name': 'ztest-cat republica $ts',
          'p_category': 'República',
        },
      );
      final after = await client
          .from('groups')
          .select('category')
          .eq('id', groupId)
          .single();
      expect(after['category'], 'República');

      await cleanup(client);
      await client.auth.signOut();
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
