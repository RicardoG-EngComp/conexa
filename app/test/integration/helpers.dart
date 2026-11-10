import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

bool get hasIntegrationCredentials =>
    Platform.environment['SUPABASE_URL'] != null &&
    Platform.environment['SUPABASE_ANON_KEY'] != null &&
    Platform.environment['TEST_USER_A_EMAIL'] != null;

Object? skipIfNoCredentials() => hasIntegrationCredentials
    ? null
    : 'Integration credentials not configured.';

SupabaseClient? createSupabaseClient() {
  final url = Platform.environment['SUPABASE_URL'];
  final key = Platform.environment['SUPABASE_ANON_KEY'];
  if (url == null || key == null) return null;
  return SupabaseClient(url, key);
}

/// Login com tolerancia ao rate limit de autenticacao (429).
DateTime? _lastSignInAt;

Future<void> signInWithRetry(
  SupabaseClient client,
  String email,
  String password,
) async {
  if (_lastSignInAt != null) {
    final gap = DateTime.now().difference(_lastSignInAt!);
    if (gap < const Duration(milliseconds: 2200)) {
      await Future<void>.delayed(const Duration(milliseconds: 2200) - gap);
    }
  }
  var attempt = 1;
  while (true) {
    _lastSignInAt = DateTime.now();
    try {
      await client.auth.signInWithPassword(email: email, password: password);
      return;
    } catch (e) {
      final isRateLimit =
          e.toString().contains('over_request_rate_limit') ||
          e.toString().contains('statusCode: 429');
      if (!isRateLimit || attempt >= 5) rethrow;
      await Future<void>.delayed(Duration(seconds: 10 * attempt));
      attempt += 1;
    }
  }
}
