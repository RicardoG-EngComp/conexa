import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  final skip = skipIfNoCredentials();

  test(
    'Usuário A não vê notificações criadas para Usuário B',
    () async {
      final supp = createSupabaseClient()!;

      final emailA = Platform.environment['TEST_USER_A_EMAIL']!;
      final passwordA = Platform.environment['TEST_USER_A_PASSWORD']!;
      final emailB = Platform.environment['TEST_USER_B_EMAIL']!;
      final passwordB = Platform.environment['TEST_USER_B_PASSWORD']!;

      await supp.auth.signInWithPassword(email: emailB, password: passwordB);
      final userB = supp.auth.currentUser!;
      await supp.auth.signOut();

      await supp.auth.signInWithPassword(email: emailA, password: passwordA);
      final userA = supp.auth.currentUser!;
      await supp.from('blocks').delete().eq('blocker_id', userA.id);
      await supp
          .from('connections')
          .delete()
          .or(
            'and(requester_id.eq.${userA.id},addressee_id.eq.${userB.id}),'
            'and(requester_id.eq.${userB.id},addressee_id.eq.${userA.id})',
          );
      await supp.rpc(
        'send_connection_request',
        params: {'target_user': userB.id},
      );
      await supp.auth.signOut();

      await supp.auth.signInWithPassword(email: emailB, password: passwordB);
      final bRows = await supp
          .from('notifications')
          .select('id')
          .eq('user_id', userB.id)
          .eq('type', 'connection_request')
          .order('created_at', ascending: false)
          .limit(1);
      String? bNotifId;
      if ((bRows as List).isNotEmpty) bNotifId = bRows.first['id'] as String;
      expect(bNotifId, isNotNull);
      await supp.auth.signOut();

      await supp.auth.signInWithPassword(email: emailA, password: passwordA);

      if (bNotifId != null) {
        final aRows = await supp
            .from('notifications')
            .select('id')
            .eq('id', bNotifId);
        expect((aRows as List).isEmpty, isTrue);
      }

      try {
        await supp.from('notifications').insert({
          'user_id': userB.id,
          'type': 'message',
          'title': 'forjada',
          'body': 'forjada',
        });
        fail('insercao direta de notificacao deveria falhar');
      } catch (_) {}

      await supp.rpc(
        'cancel_connection_request',
        params: {'p_target_user': userB.id},
      );
      await supp.auth.signOut();
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test(
    'Usuário A não vê device_tokens de Usuário B',
    () async {
      final supp = createSupabaseClient()!;

      final emailB = Platform.environment['TEST_USER_B_EMAIL']!;
      final passwordB = Platform.environment['TEST_USER_B_PASSWORD']!;
      await supp.auth.signInWithPassword(email: emailB, password: passwordB);

      final token = 'rls-token-${DateTime.now().millisecondsSinceEpoch}';
      await supp.rpc(
        'register_device_token',
        params: {'p_token': token, 'p_platform': 'android'},
      );
      await supp.auth.signOut();

      final emailA = Platform.environment['TEST_USER_A_EMAIL']!;
      final passwordA = Platform.environment['TEST_USER_A_PASSWORD']!;
      await supp.auth.signInWithPassword(email: emailA, password: passwordA);

      final rows = await supp
          .from('device_tokens')
          .select('token')
          .eq('token', token);
      expect((rows as List).isEmpty, isTrue);

      await supp.auth.signOut();
      await supp.auth.signInWithPassword(email: emailB, password: passwordB);
      await supp.rpc('unregister_device_token', params: {'p_token': token});
      await supp.auth.signOut();
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
