import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/block_repository.dart';

final blockRepositoryProvider = Provider<BlockRepository>(
  (ref) => BlockRepository(Supabase.instance.client),
);

final blockedUsersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>(
      (ref) => ref.read(blockRepositoryProvider).listBlocked(),
    );
