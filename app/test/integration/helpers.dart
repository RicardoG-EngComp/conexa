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
