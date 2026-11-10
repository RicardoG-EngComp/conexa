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
    'mark_notification_read não lança exceção para notificação inexistente',
    () async {
      final supp = createSupabaseClient()!;
      final emailA = Platform.environment['TEST_USER_A_EMAIL']!;
      final passwordA = Platform.environment['TEST_USER_A_PASSWORD']!;
      await supp.auth.signInWithPassword(email: emailA, password: passwordA);

      // mark_notification_read com ID inexistente não deve lançar exceção
      // (a secdefiner function simplesmente não encontra registros).
      await supp.rpc(
        'mark_notification_read',
        params: {'p_notification_id': '00000000-0000-0000-0000-000000000000'},
      );

      // Se chegou até aqui sem exceção, o teste passa.
      expect(supp.auth.currentUser, isNotNull);

      await supp.auth.signOut();
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 30)),
  );

  test(
    'mark_all_notifications_read não lança exceção para usuário autenticado',
    () async {
      final supp = createSupabaseClient()!;
      final emailA = Platform.environment['TEST_USER_A_EMAIL']!;
      final passwordA = Platform.environment['TEST_USER_A_PASSWORD']!;
      await supp.auth.signInWithPassword(email: emailA, password: passwordA);

      await supp.rpc('mark_all_notifications_read');

      expect(supp.auth.currentUser, isNotNull);
      await supp.auth.signOut();
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
