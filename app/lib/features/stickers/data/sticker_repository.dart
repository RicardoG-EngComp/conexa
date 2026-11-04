import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'sticker_models.dart';

class StickerRepository {
  StickerRepository(this._client);

  final SupabaseClient _client;

  Future<List<StickerPack>> fetchPacks() async {
    final rows = await _client
        .from('sticker_packs')
        .select('id, name, is_public, source')
        .order('name');
    return (rows as List)
        .map((r) => StickerPack.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<List<StickerItem>> fetchStickers(String packId) async {
    final rows = await _client
        .from('stickers')
        .select('id, pack_id, image_path, emoji')
        .eq('pack_id', packId)
        .order('sort_order');
    return (rows as List)
        .map((r) => StickerItem.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  String publicUrl(String path) {
    return _client.storage.from('stickers').getPublicUrl(path);
  }

  Future<void> sendSticker({
    required String conversationId,
    required String stickerPath,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    await _client.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': user.id,
      'content': '',
      'kind': 'sticker',
      'sticker_path': stickerPath,
    });
  }

  Future<void> sendGif({
    required String conversationId,
    required String gifUrl,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    await _client.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': user.id,
      'content': '',
      'kind': 'gif',
      'gif_url': gifUrl,
    });
  }

  Future<List<GiphyItem>> searchGiphy({
    required String query,
    required String type,
  }) async {
    final response = await _client.functions.invoke(
      'giphy-search',
      body: {'q': query, 'type': type},
    );
    final data = response.data;
    if (data is Map && data['results'] is List) {
      return (data['results'] as List)
          .map((r) => GiphyItem.fromMap(r as Map<String, dynamic>))
          .toList();
    }
    if (data is List) {
      return data
          .map((r) => GiphyItem.fromMap(r as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<String> createPack(String name) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('sem sessao');
    final row = await _client
        .from('sticker_packs')
        .insert({
          'name': name,
          'owner_id': user.id,
          'is_public': false,
          'source': 'user',
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  Future<void> uploadSticker({
    required String packId,
    required String userId,
    required Uint8List bytes,
  }) async {
    final name = '${DateTime.now().microsecondsSinceEpoch}.png';
    final path = '$userId/packs/$packId/$name';
    await _client.storage.from('stickers').uploadBinary(
      path,
      bytes,
      fileOptions: const FileOptions(
        contentType: 'image/png',
        upsert: true,
      ),
    );
    await _client.from('stickers').insert({
      'pack_id': packId,
      'image_path': path,
    });
  }
}
