import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/security_repository.dart';

final securityRepositoryProvider = Provider<SecurityRepository>(
  (ref) => SecurityRepository(Supabase.instance.client),
);

final devicesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>(
  (ref) => ref.read(securityRepositoryProvider).fetchDevices(),
);

final mutedUsersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>(
      (ref) => ref.read(securityRepositoryProvider).listMutedUsers(),
    );

final mutedWordsProvider = FutureProvider.autoDispose<List<String>>(
  (ref) => ref.read(securityRepositoryProvider).listMutedWords(),
);
