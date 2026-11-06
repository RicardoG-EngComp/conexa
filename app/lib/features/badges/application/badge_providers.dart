import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/badge_models.dart';
import '../data/badge_repository.dart';

final badgeRepositoryProvider = Provider<BadgeRepository>(
  (ref) => BadgeRepository(Supabase.instance.client),
);

final userBadgesProvider =
    FutureProvider.autoDispose.family<List<ProfileBadge>, String>(
  (ref, userId) =>
      ref.read(badgeRepositoryProvider).fetchForUser(userId),
);
