import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/feed_models.dart';
import '../data/feed_repository.dart';

final feedRepositoryProvider = Provider<FeedRepository>(
  (ref) => FeedRepository(Supabase.instance.client),
);

final feedForYouProvider = FutureProvider.autoDispose<List<FeedPost>>(
  (ref) => ref.read(feedRepositoryProvider).fetchForYou(),
);

final feedConnectionsProvider = FutureProvider.autoDispose<List<FeedPost>>(
  (ref) => ref.read(feedRepositoryProvider).fetchConnections(),
);

final topicsProvider = FutureProvider.autoDispose<List<FeedTopic>>(
  (ref) => ref.read(feedRepositoryProvider).fetchTopics(),
);

final commentsProvider = FutureProvider.autoDispose
    .family<List<FeedComment>, String>(
      (ref, postId) => ref.read(feedRepositoryProvider).fetchComments(postId),
    );
