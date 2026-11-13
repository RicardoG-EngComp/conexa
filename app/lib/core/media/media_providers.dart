import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'media_cache.dart';
import 'media_models.dart';
import 'media_service.dart';

final mediaServiceProvider = Provider<MediaService>((ref) {
  final client = Supabase.instance.client;
  final service = MediaService(client);
  final subscription = client.auth.onAuthStateChange.listen((state) {
    if (state.event == AuthChangeEvent.signedOut ||
        state.event == AuthChangeEvent.signedIn) {
      service.clearCache();
    }
    if (state.event == AuthChangeEvent.signedOut) {
      unawaited(clearMediaDiskCache());
    }
  });

  ref.onDispose(() {
    subscription.cancel();
    service.clearCache();
  });
  return service;
});

final mediaVariantsProvider = FutureProvider.autoDispose
    .family<MediaVariants?, String>(
      (ref, path) => ref.read(mediaServiceProvider).signedVariants(path),
    );
