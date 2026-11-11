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

/// Remove qualquer conexao entre dois usuarios (o chamador precisa ser um deles).
Future<void> deleteConnectionBetween(
  SupabaseClient client,
  String a,
  String b,
) async {
  try {
    await client
        .from('connections')
        .delete()
        .or(
          'and(requester_id.eq.$a,addressee_id.eq.$b),'
          'and(requester_id.eq.$b,addressee_id.eq.$a)',
        );
  } catch (_) {}
}

/// Conecta os dois usuarios, cria convite direcionado e faz o convidado entrar.
/// Ao final remove a conexao (convites in-app exigem conexao aceita).
Future<void> inviteUserToGroup(
  SupabaseClient client, {
  required String groupId,
  required String inviterId,
  required String targetUserId,
  required Future<void> Function() signInInviter,
  required Future<void> Function() signInTarget,
}) async {
  await signInInviter();
  await deleteConnectionBetween(client, inviterId, targetUserId);
  await client.rpc(
    'send_connection_request',
    params: {'target_user': targetUserId},
  );
  await signInTarget();
  await client.rpc(
    'respond_connection_request',
    params: {'requester': inviterId, 'accept': true},
  );

  await signInInviter();
  final inviteId = await client.rpc(
    'create_group_invite_for_user',
    params: {'p_group_id': groupId, 'p_target_user_id': targetUserId},
  ) as String;

  await signInTarget();
  await client.rpc('accept_group_invite', params: {'p_invite_id': inviteId});

  await signInInviter();
  await deleteConnectionBetween(client, inviterId, targetUserId);
}

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
