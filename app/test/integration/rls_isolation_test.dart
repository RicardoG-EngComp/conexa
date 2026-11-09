import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  final skip = skipIfNoCredentials();

  test(
    'Usuário A não vê notificações criadas para Usuário B',
    () async {
      final supp = createSupabaseClient()!;

      final emailB = Platform.environment['TEST_USER_B_EMAIL']!;
      final passwordB = Platform.environment['TEST_USER_B_PASSWORD']!;
      await supp.auth.signInWithPassword(email: emailB, password: passwordB);
      final userB = supp.auth.currentUser!;

      await supp.rpc(
        'enqueue_notification',
        params: {
          'p_user_id': userB.id,
          'p_type': 'message',
          'p_title': 'RLS test',
          'p_body': 'RLS body',
        },
      );

      final bRows = await supp
          .from('notifications')
          .select('id')
          .eq('user_id', userB.id)
          .eq('title', 'RLS test');
      String? bNotifId;
      if ((bRows as List).isNotEmpty) bNotifId = bRows.first['id'] as String;

      if (bNotifId != null) {
        await supp.from('notifications').delete().eq('id', bNotifId);
      }
      await supp.auth.signOut();

      final emailA = Platform.environment['TEST_USER_A_EMAIL']!;
      final passwordA = Platform.environment['TEST_USER_A_PASSWORD']!;
      await supp.auth.signInWithPassword(email: emailA, password: passwordA);

      if (bNotifId != null) {
        final aRows = await supp
            .from('notifications')
            .select('id')
            .eq('id', bNotifId);
        expect((aRows as List).isEmpty, isTrue);
      }

      await supp.auth.signOut();
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 30)),
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
