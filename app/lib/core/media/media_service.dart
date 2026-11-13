import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';
import 'media_models.dart';

class MediaService {
  MediaService(this._client);

  final SupabaseClient _client;
  final Map<String, _CachedVariants> _cache = {};
  final Map<String, Completer<MediaVariants?>> _pending = {};

  Timer? _flushTimer;

  static const int _maxBatch = 20;
  static const Duration _refreshBefore = Duration(minutes: 10);

  Future<MediaVariants?> signedVariants(String path) {
    if (path.isEmpty) return Future.value(null);

    final cached = _cache[path];
    if (cached != null &&
        cached.expiresAt.isAfter(DateTime.now().add(_refreshBefore))) {
      return Future.value(cached.variants);
    }

    final completer = _pending.putIfAbsent(
      path,
      () => Completer<MediaVariants?>(),
    );
    _flushTimer ??= Timer(const Duration(milliseconds: 20), () {
      _flushTimer = null;
      unawaited(_flush());
    });
    return completer.future;
  }

  Future<Map<String, MediaVariants>> signProfilePaths(
    List<String> paths,
  ) async {
    final now = DateTime.now();
    final result = <String, MediaVariants>{};
    final missing = <String>[];

    for (final path in paths.toSet()) {
      final cached = _cache[path];
      if (cached != null && cached.expiresAt.isAfter(now.add(_refreshBefore))) {
        result[path] = cached.variants;
      } else {
        missing.add(path);
      }
    }

    if (missing.isEmpty) return result;

    final response = await _client.functions.invoke(
      'media-sign',
      body: {'paths': missing},
    );
    final data = response.data;
    if (data is! Map) throw const MediaException('resposta_invalida');

    final items = data['items'];
    if (items is! Map) throw const MediaException('resposta_invalida');

    final expiresIn = (data['expiresIn'] as num?)?.toInt() ?? 86400;
    final expiresAt = now.add(Duration(seconds: expiresIn));

    for (final entry in items.entries) {
      final key = entry.key;
      final value = entry.value;
      if (key is! String || value is! Map) continue;

      final full = value['full'];
      final thumb = value['thumb'];
      if (full is! String || full.isEmpty) continue;

      final variants = MediaVariants(
        full: full,
        thumb: thumb is String && thumb.isNotEmpty ? thumb : full,
      );
      _cache[key] = _CachedVariants(variants, expiresAt);
      result[key] = variants;
    }

    return result;
  }

  Future<MediaUploadResult> uploadImage({
    required Uint8List bytes,
    required String kind,
    required String variant,
    required String contentType,
    String? assetId,
    int? width,
    int? height,
  }) async {
    final session = _client.auth.currentSession;
    if (session == null) throw const MediaException('sem_sessao');

    final uri = Uri.parse('${Env.supabaseUrl}/functions/v1/media-upload');
    final headers = <String, String>{
      'Authorization': 'Bearer ${session.accessToken}',
      'apikey': Env.supabaseAnonKey,
      'Content-Type': contentType,
      'x-kind': kind,
      'x-variant': variant,
    };
    if (assetId != null) headers['x-asset-id'] = assetId;
    if (width != null) headers['x-width'] = '$width';
    if (height != null) headers['x-height'] = '$height';

    final response = await http.post(uri, headers: headers, body: bytes);
    final data = _decodeJson(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MediaException(
        (data['error'] as String?) ?? 'upload_failed',
        status: response.statusCode,
      );
    }

    return MediaUploadResult.fromMap(data);
  }

  Future<void> deletePaths({
    required String scope,
    required List<String> paths,
  }) async {
    if (paths.isEmpty) return;

    try {
      await _client.functions.invoke(
        'media-delete',
        body: {'scope': scope, 'paths': paths},
      );
      for (final path in paths) {
        _cache.remove(path);
      }
    } on FunctionException catch (error) {
      throw MediaException('delete_failed', status: error.status);
    }
  }

  void clearCache() {
    _cache.clear();
    _flushTimer?.cancel();
    _flushTimer = null;
    for (final completer in _pending.values) {
      if (!completer.isCompleted) completer.complete(null);
    }
    _pending.clear();
  }

  Future<void> _flush() async {
    final batch = Map<String, Completer<MediaVariants?>>.from(_pending);
    _pending.clear();
    final paths = batch.keys.toList(growable: false);

    for (var i = 0; i < paths.length; i += _maxBatch) {
      final end = i + _maxBatch < paths.length ? i + _maxBatch : paths.length;
      final chunk = paths.sublist(i, end);

      try {
        final result = await signProfilePaths(chunk);
        for (final path in chunk) {
          final completer = batch[path];
          if (completer != null && !completer.isCompleted) {
            completer.complete(result[path]);
          }
        }
      } catch (error, stackTrace) {
        for (final path in chunk) {
          final completer = batch[path];
          if (completer != null && !completer.isCompleted) {
            completer.completeError(error, stackTrace);
          }
        }
      }
    }
  }
}

class _CachedVariants {
  const _CachedVariants(this.variants, this.expiresAt);

  final MediaVariants variants;
  final DateTime expiresAt;
}

Map<String, dynamic> _decodeJson(String body) {
  if (body.isEmpty) return const {};
  try {
    final decoded = jsonDecode(body);
    return decoded is Map<String, dynamic> ? decoded : const {};
  } catch (_) {
    return const {};
  }
}
