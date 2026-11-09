import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  final skip = skipIfNoCredentials();

  test(
    'submit_beta_signup aceita campus com acento',
    () async {
      final supp = createSupabaseClient()!;
      final result = await supp.rpc(
        'submit_beta_signup',
        params: {
          'p_name': 'Teste Integracao',
          'p_ufv_email': 'test.integration.form@alunos.ufv.br',
          'p_gmail': 'test.integration.form@gmail.com',
          'p_course': 'Administracao',
          'p_campus': 'Vicosa',
          'p_gender': 'Outro',
          'p_how_heard': 'Teste',
          'p_difficulty': 'Teste',
          'p_website': '',
          'p_age': true,
          'p_android': true,
          'p_four_weeks': true,
          'p_consent_independent': true,
          'p_consent_firebase': true,
          'p_consent_privacy': true,
        },
      ) as Map<String, dynamic>;

      expect(result['ok'], isTrue);
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 30)),
  );

  test(
    'submit_beta_signup retorna duplicate para email repetido',
    () async {
      final supp = createSupabaseClient()!;

      final email = 'test.integration.form@alunos.ufv.br';
      try {
        await supp.rpc(
          'submit_beta_signup',
          params: {
            'p_name': 'Teste Integracao 2',
            'p_ufv_email': email,
            'p_gmail': 'test.integration.form2@gmail.com',
            'p_course': 'Administracao',
            'p_campus': 'Florestal',
            'p_gender': 'Outro',
            'p_how_heard': 'Teste',
            'p_difficulty': 'Teste',
            'p_website': '',
            'p_age': true,
            'p_android': true,
            'p_four_weeks': true,
            'p_consent_independent': true,
            'p_consent_firebase': true,
            'p_consent_privacy': true,
          },
        );
      } catch (_) {}

      final result = await supp.rpc(
        'submit_beta_signup',
        params: {
          'p_name': 'Teste Integracao 3',
          'p_ufv_email': email,
          'p_gmail': 'test.integration.form3@gmail.com',
          'p_course': 'Administracao',
          'p_campus': 'Florestal',
          'p_gender': 'Outro',
          'p_how_heard': 'Teste',
          'p_difficulty': 'Teste',
          'p_website': '',
          'p_age': true,
          'p_android': true,
          'p_four_weeks': true,
          'p_consent_independent': true,
          'p_consent_firebase': true,
          'p_consent_privacy': true,
        },
      ) as Map<String, dynamic>;

      expect(result['ok'], isFalse);
      expect(result['code'], 'duplicate');
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
