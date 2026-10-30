import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  static const String consentVersion = '2026-10';

  String get redirectTo => kIsWeb
      ? 'http://localhost:8081'
      : 'com.ricardogengcomp.match://login-callback';

  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) {
    return _client.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: redirectTo,
    );
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<void> resetPassword(String email) {
    return _client.auth.resetPasswordForEmail(email, redirectTo: redirectTo);
  }

  Future<bool> hasConsents() async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    final rows = await _client
        .from('consents')
        .select('id')
        .eq('user_id', user.id)
        .limit(1);
    return (rows as List).isNotEmpty;
  }

  Future<void> saveConsents(List<String> types) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    final rows = types
        .map(
          (type) => {
            'user_id': user.id,
            'type': type,
            'version': consentVersion,
          },
        )
        .toList();
    await _client.from('consents').insert(rows);
  }
}
