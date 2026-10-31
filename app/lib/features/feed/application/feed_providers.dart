import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/feed_models.dart';
import '../data/feed_repository.dart';

final feedRepositoryProvider = Provider<FeedRepository>(
  (ref) => FeedRepository(Supabase.instance.client),
);

final feedProvider = FutureProvider.autoDispose<List<FeedPost>>(
  (ref) => ref.read(feedRepositoryProvider).fetchPosts(),
);

final commentsProvider = FutureProvider.autoDispose
    .family<List<FeedComment>, String>(
      (ref, postId) => ref.read(feedRepositoryProvider).fetchComments(postId),
    );
