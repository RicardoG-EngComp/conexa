import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

final emailA = Platform.environment['TEST_USER_A_EMAIL'] ?? '';
final passwordA = Platform.environment['TEST_USER_A_PASSWORD'] ?? '';
final emailB = Platform.environment['TEST_USER_B_EMAIL'] ?? '';
final passwordB = Platform.environment['TEST_USER_B_PASSWORD'] ?? '';

void main() {
  final skip = skipIfNoCredentials();

  test(
    'Contas de teste conseguem fazer login no Supabase',
    () async {
      final client = createSupabaseClient()!;

      await client.auth.signInWithPassword(email: emailA, password: passwordA);
      expect(client.auth.currentUser, isNotNull);
      await client.auth.signOut();

      await client.auth.signInWithPassword(email: emailB, password: passwordB);
      expect(client.auth.currentUser, isNotNull);
      await client.auth.signOut();
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
