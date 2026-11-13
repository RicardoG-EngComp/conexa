import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/profile_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(Supabase.instance.client),
);

final catalogProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>(
  (ref) => ref.read(profileRepositoryProvider).fetchCatalog(),
);

final favoriteIdsProvider = FutureProvider.autoDispose
    .family<Set<String>, String>(
      (ref, userId) =>
          ref.read(profileRepositoryProvider).fetchFavoriteIds(userId),
    );

final publicProfileProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, String>(
      (ref, id) => ref.read(profileRepositoryProvider).fetchPublic(id),
    );
