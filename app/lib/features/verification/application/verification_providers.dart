import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/verification_repository.dart';

final verificationRepositoryProvider = Provider<VerificationRepository>(
  (ref) => VerificationRepository(Supabase.instance.client),
);

final profileProvider = FutureProvider.autoDispose<Map<String, dynamic>?>(
  (ref) => ref.read(verificationRepositoryProvider).fetchProfile(),
);
