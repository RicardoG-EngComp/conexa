import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class VerificationRepository {
  VerificationRepository(this._client);

  final SupabaseClient _client;

  Future<void> uploadImage({
    required String userId,
    required String name,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    await _client.storage
        .from('verification-docs')
        .uploadBinary(
          '$userId/$name',
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
  }

  Future<Map<String, dynamic>> verifyCin(String? qr) async {
    final response = await _client.functions.invoke(
      'verify-cin',
      body: {'qr': qr},
    );
    final data = response.data;
    if (data is Map<String, dynamic>) return data;
    return {'ok': false};
  }

  Future<Map<String, dynamic>?> fetchProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    final data = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();
    return data;
  }
}
