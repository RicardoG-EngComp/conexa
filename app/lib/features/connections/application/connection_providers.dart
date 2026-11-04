import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/connection_models.dart';
import '../data/connection_repository.dart';

final connectionRepositoryProvider = Provider<ConnectionRepository>(
  (ref) => ConnectionRepository(Supabase.instance.client),
);

final connectionsProvider = FutureProvider.autoDispose<ConnectionsData>(
  (ref) => ref.read(connectionRepositoryProvider).fetch(),
);

final connectionStatusProvider = FutureProvider.autoDispose
    .family<ConnectionStatus, String>(
      (ref, targetId) =>
          ref.read(connectionRepositoryProvider).statusWith(targetId),
    );
