import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/media/media_models.dart';

class ChatMediaService {
  ChatMediaService(this._client);

  final SupabaseClient _client;
  final Map<String, _Cached> _cache = {};
  final Map<String, Completer<MediaVariants?>> _pending = {};
  Timer? _timer;

  Future<MediaVariants?> signed(String path) {
    if (path.isEmpty) return Future.value(null);
    final cached = _cache[path];
    if (cached != null &&
        cached.expiresAt.isAfter(
          DateTime.now().add(const Duration(minutes: 10)),
        )) {
      return Future.value(cached.variants);
    }
    final completer = _pending.putIfAbsent(path, Completer.new);
    _timer ??= Timer(const Duration(milliseconds: 20), () {
      _timer = null;
      unawaited(_flush());
    });
    return completer.future;
  }

  Future<void> _flush() async {
    final batch = Map<String, Completer<MediaVariants?>>.from(_pending);
    _pending.clear();
    if (batch.isEmpty) return;

    final paths = batch.keys.toList(growable: false);
    for (var i = 0; i < paths.length; i += 20) {
      final end = i + 20 < paths.length ? i + 20 : paths.length;
      final chunk = paths.sublist(i, end);
      try {
        final response = await _client.functions.invoke(
          'chat-media-sign',
          body: {'paths': chunk},
        );
        final data = response.data;
        final items = data is Map ? data['items'] : null;
        final expiresIn = data is Map
            ? ((data['expiresIn'] as num?)?.toInt() ?? 3600)
            : 3600;
        final expiresAt = DateTime.now().add(Duration(seconds: expiresIn));
        for (final path in chunk) {
          final value = items is Map ? items[path] : null;
          if (value is! Map) {
            batch[path]?.complete(null);
            continue;
          }
          final full = value['full'];
          if (full is! String || full.isEmpty) {
            batch[path]?.complete(null);
            continue;
          }
          final variants = MediaVariants(full: full, thumb: full);
          _cache[path] = _Cached(variants, expiresAt);
          batch[path]?.complete(variants);
        }
      } catch (error, stack) {
        for (final path in chunk) {
          final completer = batch[path];
          if (completer != null && !completer.isCompleted) {
            completer.completeError(error, stack);
          }
        }
      }
    }
  }

  void clear() {
    _cache.clear();
    _timer?.cancel();
    _timer = null;
    for (final completer in _pending.values) {
      if (!completer.isCompleted) completer.complete(null);
    }
    _pending.clear();
  }

  void invalidate(String path) {
    _cache.remove(path);
  }

  Future<MediaVariants?> refresh(String path) async {
    invalidate(path);
    return signed(path);
  }
}

class _Cached {
  const _Cached(this.variants, this.expiresAt);

  final MediaVariants variants;
  final DateTime expiresAt;
}

final chatMediaServiceProvider = Provider<ChatMediaService>((ref) {
  final service = ChatMediaService(Supabase.instance.client);
  final sub = Supabase.instance.client.auth.onAuthStateChange.listen((state) {
    if (state.event == AuthChangeEvent.signedOut ||
        state.event == AuthChangeEvent.signedIn) {
      service.clear();
    }
  });
  ref.onDispose(() {
    sub.cancel();
    service.clear();
  });
  return service;
});

final chatMediaVariantsProvider = FutureProvider.autoDispose
    .family<MediaVariants?, String>(
      (ref, path) => ref.read(chatMediaServiceProvider).signed(path),
    );
