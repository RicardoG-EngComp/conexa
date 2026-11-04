import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/connection_models.dart';
import '../data/connection_repository.dart';

final connectionRepositoryProvider = Provider<ConnectionRepository>(
  (ref) => ConnectionRepository(Supabase.instance.client),
);

final connectionsProvider =
    StreamProvider.autoDispose<ConnectionsData>((ref) {
  final repository = ref.read(connectionRepositoryProvider);
  final client = Supabase.instance.client;
  final controller = StreamController<ConnectionsData>();
  var disposed = false;

  Future<void> refresh() async {
    try {
      final data = await repository.fetch();
      if (!disposed) controller.add(data);
    } catch (error, stack) {
      if (!disposed) controller.addError(error, stack);
    }
  }

  refresh();
  final subscription = client
      .from('connections')
      .stream(primaryKey: ['requester_id', 'addressee_id'])
      .listen((_) => refresh());

  ref.onDispose(() {
    disposed = true;
    subscription.cancel();
    controller.close();
  });

  return controller.stream;
});

final connectionStatusProvider =
    FutureProvider.autoDispose.family<ConnectionStatus, String>(
  (ref, targetId) =>
      ref.read(connectionRepositoryProvider).statusWith(targetId),
);
