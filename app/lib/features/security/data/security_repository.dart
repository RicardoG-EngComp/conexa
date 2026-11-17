import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/uuid.dart';

class SecurityRepository {
  SecurityRepository(this._client);

  final SupabaseClient _client;

  static const _deviceKey = 'conexa_device_id';

  Future<void> registerCurrentDevice() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    final prefs = await SharedPreferences.getInstance();
    var deviceId = prefs.getString(_deviceKey);
    if (deviceId == null || deviceId.length < 8) {
      deviceId = uuidV4();
      await prefs.setString(_deviceKey, deviceId);
    }
    final info = await PackageInfo.fromPlatform();
    final platform = kIsWeb
        ? 'web'
        : switch (defaultTargetPlatform) {
            TargetPlatform.android => 'android',
            TargetPlatform.iOS => 'ios',
            _ => 'unknown',
          };
    final platformLabel = switch (platform) {
      'android' => 'Android',
      'ios' => 'iOS',
      'web' => 'Web',
      _ => 'Dispositivo',
    };
    await _client.rpc(
      'register_device_session',
      params: {
        'p_device_id': deviceId,
        'p_label': '$platformLabel · Conexa ${info.version}',
        'p_platform': platform,
      },
    );
  }

  Future<List<Map<String, dynamic>>> fetchDevices() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];
    final rows = await _client
        .from('user_devices')
        .select('device_id, label, platform, created_at, last_seen_at')
        .eq('user_id', user.id)
        .order('last_seen_at', ascending: false);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> signOutEverywhere() async {
    await _client.auth.signOut(scope: SignOutScope.global);
  }

  Future<Map<String, dynamic>> exportMyData() async {
    final result = await _client.rpc('export_my_data');
    return (result as Map).cast<String, dynamic>();
  }

  Future<List<Map<String, dynamic>>> listMutedUsers() async {
    final rows = await _client.rpc('list_muted_users');
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> muteUser(String userId) async {
    await _client.rpc('mute_user', params: {'p_target': userId});
  }

  Future<void> unmuteUser(String userId) async {
    await _client.rpc('unmute_user', params: {'p_target': userId});
  }

  Future<List<String>> listMutedWords() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];
    final rows = await _client
        .from('muted_words')
        .select('word')
        .eq('user_id', user.id)
        .order('word');
    return (rows as List).map((r) => r['word'] as String).toList();
  }

  Future<void> addMutedWord(String word) async {
    await _client.rpc('add_muted_word', params: {'p_word': word});
  }

  Future<void> removeMutedWord(String word) async {
    await _client.rpc('remove_muted_word', params: {'p_word': word});
  }
}
