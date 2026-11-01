import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient _client;

  Future<Map<String, dynamic>?> fetchOwn() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    return await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    await _client.from('profiles').update(data).eq('id', user.id);
  }

  Future<String> uploadImage({
    required String path,
    required Uint8List bytes,
  }) async {
    await _client.storage
        .from('profile-media')
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );
    return path;
  }

  Future<String?> signedUrl(String path) async {
    if (path.isEmpty) return null;
    try {
      return await _client.storage
          .from('profile-media')
          .createSignedUrl(path, 3600);
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteImage(String path) async {
    try {
      await _client.storage.from('profile-media').remove([path]);
    } catch (_) {
      // ignora
    }
  }

  Future<List<Map<String, dynamic>>> fetchCatalog() async {
    final rows = await _client
        .from('catalog_items')
        .select('id, category, name')
        .order('category')
        .order('sort_order');
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<Set<String>> fetchFavoriteIds(String userId) async {
    final rows = await _client
        .from('profile_favorites')
        .select('item_id')
        .eq('user_id', userId);
    return (rows as List).map((r) => r['item_id'] as String).toSet();
  }

  Future<void> saveFavorites(List<String> itemIds) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    await _client.from('profile_favorites').delete().eq('user_id', user.id);
    if (itemIds.isNotEmpty) {
      await _client
          .from('profile_favorites')
          .insert(
            itemIds.map((id) => {'user_id': user.id, 'item_id': id}).toList(),
          );
    }
  }

  Future<Map<String, dynamic>?> fetchPublic(String id) async {
    return await _client
        .from('profiles_public')
        .select()
        .eq('id', id)
        .maybeSingle();
  }
}
