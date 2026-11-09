import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  final skip = skipIfNoCredentials();

  test(
    'register_device_token salva e remove token',
    () async {
      final supp = createSupabaseClient()!;
      final emailA = Platform.environment['TEST_USER_A_EMAIL']!;
      final passwordA = Platform.environment['TEST_USER_A_PASSWORD']!;

      await supp.auth.signInWithPassword(email: emailA, password: passwordA);
      final userA = supp.auth.currentUser!;

      final token = 'integration-test-${DateTime.now().millisecondsSinceEpoch}';
      await supp.rpc(
        'register_device_token',
        params: {'p_token': token, 'p_platform': 'android'},
      );

      final rows = await supp
          .from('device_tokens')
          .select('token')
          .eq('user_id', userA.id)
          .eq('token', token);
      expect((rows as List).isNotEmpty, isTrue);

      await supp.rpc('unregister_device_token', params: {'p_token': token});
      final after = await supp
          .from('device_tokens')
          .select('token')
          .eq('token', token);
      expect((after as List).isEmpty, isTrue);

      await supp.auth.signOut();
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 30)),
  );

  test(
    'mark_notification_read marca notificaÃƒÂ§ÃƒÂ£o do usuÃƒÂ¡rio',
    () async {
      final supp = createSupabaseClient()!;
      final emailA = Platform.environment['TEST_USER_A_EMAIL']!;
      final passwordA = Platform.environment['TEST_USER_A_PASSWORD']!;
      await supp.auth.signInWithPassword(email: emailA, password: passwordA);
      final userA = supp.auth.currentUser!;

      await supp.rpc(
        'enqueue_notification',
        params: {
          'p_user_id': userA.id,
          'p_type': 'message',
          'p_title': 'Integration test',
          'p_body': 'Integration test body',
        },
      );

      final rows = await supp
          .from('notifications')
          .select('id')
          .eq('user_id', userA.id)
          .eq('title', 'Integration test');
      expect((rows as List).isNotEmpty, isTrue);
      final notifId = (rows as List).first['id'] as String;

      await supp.rpc(
        'mark_notification_read',
        params: {'p_notification_id': notifId},
      );
      final after = await supp
          .from('notifications')
          .select('read_at')
          .eq('id', notifId)
          .single();
      expect(after['read_at'], isNotNull);

      await supp.from('notifications').delete().eq('id', notifId);
      await supp.auth.signOut();
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
