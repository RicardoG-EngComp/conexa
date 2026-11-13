import 'dart:io';
import 'dart:typed_data';

import 'package:conexa/core/utils/uuid.dart';
import 'package:conexa/features/feedback/data/feedback_repository.dart';
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

  Future<void> cleanFeedback(SupabaseClient client, String userId) async {
    await client.from('bug_reports').delete().eq('reporter_id', userId);
    await client.from('suggestions').delete().eq('reporter_id', userId);
  }

  test(
    'feedback e isolado por dono e status so admin altera',
    () async {
      final client = createSupabaseClient()!;
      await signInB(client);
      final userB = client.auth.currentUser!.id;
      await signInA(client);
      final userA = client.auth.currentUser!.id;

      await signInAdmin(client);
      await cleanFeedback(client, userA);
      await cleanFeedback(client, userB);

      await signInA(client);
      final bugA = uuidV4();
      await client.from('bug_reports').insert({
        'id': bugA,
        'reporter_id': userA,
        'title': 'Bug de teste A',
        'description': 'Descricao do bug de teste do usuario A.',
        'platform': 'android',
        'app_version': '1.0.14+14',
      });

      await signInB(client);
      final bugB = uuidV4();
      await client.from('bug_reports').insert({
        'id': bugB,
        'reporter_id': userB,
        'title': 'Bug de teste B',
        'description': 'Descricao do bug de teste do usuario B.',
        'platform': 'android',
        'app_version': '1.0.14+14',
      });

      await signInA(client);
      final own = await client
          .from('bug_reports')
          .select('id, status')
          .eq('id', bugA);
      expect((own as List).length, 1);
      expect((own.first as Map)['status'], 'new');

      final crossRead = await client
          .from('bug_reports')
          .select('id')
          .eq('id', bugB);
      expect(crossRead as List, isEmpty);

      await client
          .from('bug_reports')
          .update({'status': 'triaged'})
          .eq('id', bugA);
      final unchanged = await client
          .from('bug_reports')
          .select('status')
          .eq('id', bugA)
          .single();
      expect(unchanged['status'], 'new');

      await signInB(client);
      final bViewsA = await client
          .from('bug_reports')
          .select('id')
          .eq('id', bugA);
      expect(bViewsA as List, isEmpty);

      await signInAdmin(client);
      final adminView = await client.from('bug_reports').select('id').inFilter(
        'id',
        [bugA, bugB],
      );
      expect((adminView as List).length, 2);
      await client
          .from('bug_reports')
          .update({'status': 'triaged'})
          .eq('id', bugA);

      await signInA(client);
      final after = await client
          .from('bug_reports')
          .select('status')
          .eq('id', bugA)
          .single();
      expect(after['status'], 'triaged');

      await signInAdmin(client);
      await cleanFeedback(client, userA);
      await cleanFeedback(client, userB);
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 120)),
  );

  test(
    'nao permite forjar autor, status, numero nem burlar checks',
    () async {
      final client = createSupabaseClient()!;
      await signInB(client);
      final userB = client.auth.currentUser!.id;
      await signInA(client);
      final userA = client.auth.currentUser!.id;

      await expectThrows(
        () => client.from('bug_reports').insert({
          'id': uuidV4(),
          'reporter_id': userB,
          'title': 'Tentativa de forjar autor',
          'description': 'Descricao suficientemente longa para o teste.',
        }),
      );

      await expectThrows(
        () => client.from('bug_reports').insert({
          'id': uuidV4(),
          'reporter_id': userA,
          'title': 'Tentativa de forjar status',
          'description': 'Descricao suficientemente longa para o teste.',
          'status': 'fixed',
        }),
      );

      await expectThrows(
        () => client.from('bug_reports').insert({
          'id': uuidV4(),
          'reporter_id': userA,
          'title': 'Tentativa de forjar numero',
          'description': 'Descricao suficientemente longa para o teste.',
          'number': 999999,
        }),
      );

      await expectThrows(
        () => client.from('bug_reports').insert({
          'id': uuidV4(),
          'reporter_id': userA,
          'title': 'Curto',
          'description': 'curta',
        }),
      );

      await expectThrows(
        () => client.from('bug_reports').insert({
          'id': uuidV4(),
          'reporter_id': userA,
          'title': 'Print de outro usuario',
          'description': 'Descricao suficientemente longa para o teste.',
          'screenshot_path': '$userB/print.jpg',
        }),
      );

      await expectThrows(
        () => client.from('bug_reports').insert({
          'id': uuidV4(),
          'reporter_id': userA,
          'title': 'Print com traversal',
          'description': 'Descricao suficientemente longa para o teste.',
          'screenshot_path': '$userA/../print.jpg',
        }),
      );

      await expectThrows(
        () => client.from('suggestions').insert({
          'id': uuidV4(),
          'reporter_id': userB,
          'title': 'Sugestao de outro autor',
          'description': 'Descricao suficientemente longa para o teste.',
        }),
      );
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 120)),
  );

  test(
    'limite de 20 envios por 24h por tipo',
    () async {
      final client = createSupabaseClient()!;
      await signInB(client);
      final userB = client.auth.currentUser!.id;
      await signInA(client);
      final userA = client.auth.currentUser!.id;

      await signInAdmin(client);
      await cleanFeedback(client, userA);
      await cleanFeedback(client, userB);
      await signInA(client);

      for (var i = 0; i < 20; i++) {
        await client.from('bug_reports').insert({
          'id': uuidV4(),
          'reporter_id': userA,
          'title': 'Limite $i teste',
          'description': 'Descricao do envio numero $i para o teste de limite.',
        });
      }

      await expectError(
        () => client.from('bug_reports').insert({
          'id': uuidV4(),
          'reporter_id': userA,
          'title': 'Limite 21 teste',
          'description': 'Descricao do envio vinte e um do teste de limite.',
        }),
        'limite_feedback',
      );

      await signInAdmin(client);
      await cleanFeedback(client, userA);
      await cleanFeedback(client, userB);
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 180)),
  );

  test(
    'exportacao e restrita a admin e nao expoe o autor',
    () async {
      final client = createSupabaseClient()!;
      await signInB(client);
      final userB = client.auth.currentUser!.id;
      await signInA(client);
      final userA = client.auth.currentUser!.id;

      await signInAdmin(client);
      await cleanFeedback(client, userA);
      await cleanFeedback(client, userB);
      await signInA(client);

      final inserted = await client
          .from('bug_reports')
          .insert({
            'id': uuidV4(),
            'reporter_id': userA,
            'title': 'Bug para exportacao',
            'description': 'Descricao do bug usada no teste de exportacao.',
          })
          .select('number')
          .single();
      final number = inserted['number'];

      await expectError(
        () => client.rpc('export_feedback', params: {'p_kind': 'bug'}),
        'forbidden',
      );

      await signInAdmin(client);
      final exported = await client.rpc(
        'export_feedback',
        params: {'p_kind': 'bug'},
      ) as List;
      final mine = exported.cast<Map<String, dynamic>>().firstWhere(
        (item) => item['number'] == number,
      );
      expect(mine['protocol'], startsWith('BUG-'));
      expect(mine.containsKey('reporter_id'), isFalse);

      await expectError(
        () => client.rpc('export_feedback', params: {'p_kind': 'tudo'}),
        'tipo_invalido',
      );

      await cleanFeedback(client, userA);
      await cleanFeedback(client, userB);
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 120)),
  );

  test(
    'repositorio envia bug com print e lista em meus envios',
    () async {
      final client = createSupabaseClient()!;
      await signInB(client);
      final userB = client.auth.currentUser!.id;
      await signInA(client);
      final userA = client.auth.currentUser!.id;

      await signInAdmin(client);
      await cleanFeedback(client, userA);
      await cleanFeedback(client, userB);
      await signInA(client);

      final repo = FeedbackRepository(client);
      String? screenshotPath;
      try {
        final entry = await repo.submitBug(
          title: 'Bug via repositorio',
          description: 'Descricao do bug enviado pelo repositorio do app.',
          platform: 'Android',
          appVersion: '1.0.14+14',
          screenshotBytes: Uint8List.fromList([1, 2, 3, 4]),
        );
        expect(entry.protocol, startsWith('BUG-'));
        expect(entry.screenshotPath, isNotNull);
        screenshotPath = entry.screenshotPath;

        final mine = await repo.fetchMine();
        expect(mine.any((item) => item.id == entry.id), isTrue);
      } finally {
        if (screenshotPath != null) {
          try {
            await client.storage.from('feedback-media').remove([
              screenshotPath,
            ]);
          } catch (_) {}
        }
        await signInAdmin(client);
        await cleanFeedback(client, userA);
        await cleanFeedback(client, userB);
      }
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 120)),
  );

  test(
    'storage de feedback e privado e restrito ao dono',
    () async {
      final client = createSupabaseClient()!;
      await signInB(client);
      final userB = client.auth.currentUser!.id;
      await signInA(client);
      final userA = client.auth.currentUser!.id;
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      final ownPath = '$userA/feedback-teste.jpg';

      try {
        await expectThrows(
          () => client.storage
              .from('feedback-media')
              .uploadBinary(
                '$userB/intruso.jpg',
                bytes,
                fileOptions: const FileOptions(contentType: 'image/jpeg'),
              ),
        );

        await expectThrows(
          () => client.storage
              .from('feedback-media')
              .uploadBinary(
                '$userA/feedback-teste.txt',
                bytes,
                fileOptions: const FileOptions(contentType: 'text/plain'),
              ),
        );

        await client.storage
            .from('feedback-media')
            .uploadBinary(
              ownPath,
              bytes,
              fileOptions: const FileOptions(contentType: 'image/jpeg'),
            );

        await signInB(client);
        await expectThrows(
          () => client.storage.from('feedback-media').download(ownPath),
        );

        await signInAdmin(client);
        final adminDownload = await client.storage
            .from('feedback-media')
            .download(ownPath);
        expect(adminDownload.length, bytes.length);

        await signInA(client);
        await client.storage.from('feedback-media').remove([ownPath]);
      } finally {
        await client.auth.signOut();
      }
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 120)),
  );
}
