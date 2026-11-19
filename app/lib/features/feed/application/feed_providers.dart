import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/feed_models.dart';
import '../data/feed_repository.dart';

final feedRepositoryProvider = Provider<FeedRepository>(
  (ref) => FeedRepository(Supabase.instance.client),
);

final feedForYouProvider =
    AsyncNotifierProvider.autoDispose<FeedForYouNotifier, List<FeedPost>>(
      FeedForYouNotifier.new,
    );

final feedConnectionsProvider =
    AsyncNotifierProvider.autoDispose<FeedConnectionsNotifier, List<FeedPost>>(
      FeedConnectionsNotifier.new,
    );

abstract class FeedNotifier extends AsyncNotifier<List<FeedPost>> {
  Future<List<FeedPost>> fetchFeed();

  @override
  Future<List<FeedPost>> build() => fetchFeed();

  Future<void> toggleLike(String postId) async {
    final snapshot = state.asData?.value;
    if (snapshot == null) return;
    final index = snapshot.indexWhere((post) => post.id == postId);
    if (index < 0) return;

    final post = snapshot[index];
    final liked = !post.likedByMe;
    final optimistic = [...snapshot];
    optimistic[index] = post.copyWith(
      likedByMe: liked,
      likeCount: liked
          ? post.likeCount + 1
          : (post.likeCount > 0 ? post.likeCount - 1 : 0),
    );
    state = AsyncData(optimistic);

    try {
      await ref.read(feedRepositoryProvider).toggleLike(postId, post.likedByMe);
    } catch (_) {
      if (ref.mounted) state = AsyncData(snapshot);
    }
  }

  Future<void> toggleBookmark(String postId) async {
    final snapshot = state.asData?.value;
    if (snapshot == null) return;
    final index = snapshot.indexWhere((post) => post.id == postId);
    if (index < 0) return;

    final post = snapshot[index];
    final optimistic = [...snapshot];
    optimistic[index] = post.copyWith(bookmarked: !post.bookmarked);
    state = AsyncData(optimistic);

    try {
      final bookmarked = await ref
          .read(feedRepositoryProvider)
          .toggleBookmark(postId);
      if (!ref.mounted) return;
      final current = state.asData?.value;
      if (current == null) return;
      final currentIndex = current.indexWhere((item) => item.id == postId);
      if (currentIndex < 0) return;
      final updated = [...current];
      updated[currentIndex] = current[currentIndex].copyWith(
        bookmarked: bookmarked,
      );
      state = AsyncData(updated);
    } catch (_) {
      if (ref.mounted) state = AsyncData(snapshot);
    }
  }
}

class FeedForYouNotifier extends FeedNotifier {
  @override
  Future<List<FeedPost>> fetchFeed() =>
      ref.read(feedRepositoryProvider).fetchForYou();
}

class FeedConnectionsNotifier extends FeedNotifier {
  @override
  Future<List<FeedPost>> fetchFeed() =>
      ref.read(feedRepositoryProvider).fetchConnections();
}

final savedPostsProvider = FutureProvider.autoDispose<List<FeedPost>>(
  (ref) => ref.read(feedRepositoryProvider).fetchBookmarked(),
);

final hiddenPostsProvider = FutureProvider.autoDispose<List<FeedPost>>(
  (ref) => ref.read(feedRepositoryProvider).fetchNotInterested(),
);

final customFeedsProvider = FutureProvider.autoDispose<List<CustomFeed>>(
  (ref) => ref.read(feedRepositoryProvider).fetchCustomFeeds(),
);

final customFeedPostsProvider = FutureProvider.autoDispose
    .family<List<FeedPost>, String>(
      (ref, feedId) => ref.read(feedRepositoryProvider).fetchCustomFeed(feedId),
    );

final myAnalyticsProvider = FutureProvider.autoDispose<Map<String, dynamic>>(
  (ref) => ref.read(feedRepositoryProvider).myAnalytics(),
);

final myViewsProvider = FutureProvider.autoDispose<Map<String, dynamic>>(
  (ref) => ref.read(feedRepositoryProvider).myViewsSummary(),
);

final topicsProvider = FutureProvider.autoDispose<List<FeedTopic>>(
  (ref) => ref.read(feedRepositoryProvider).fetchTopics(),
);

final commentsProvider = FutureProvider.autoDispose
    .family<List<FeedComment>, String>(
      (ref, postId) => ref.read(feedRepositoryProvider).fetchComments(postId),
    );
