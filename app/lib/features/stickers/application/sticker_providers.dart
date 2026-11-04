import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/sticker_models.dart';
import '../data/sticker_repository.dart';

final stickerRepositoryProvider = Provider<StickerRepository>(
  (ref) => StickerRepository(Supabase.instance.client),
);

final stickerPacksProvider = FutureProvider.autoDispose<List<StickerPack>>(
  (ref) => ref.read(stickerRepositoryProvider).fetchPacks(),
);

final stickersProvider =
    FutureProvider.autoDispose.family<List<StickerItem>, String>(
  (ref, packId) =>
      ref.read(stickerRepositoryProvider).fetchStickers(packId),
);
