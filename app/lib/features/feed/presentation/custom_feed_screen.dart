import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../reports/presentation/report_dialog.dart';
import '../application/feed_providers.dart';
import '../data/feed_models.dart';
import 'feed_post_card.dart';

class CustomFeedScreen extends ConsumerWidget {
  const CustomFeedScreen({super.key, required this.feedId, this.feed});

  final String feedId;
  final CustomFeed? feed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(customFeedPostsProvider(feedId));

    return Scaffold(
      appBar: AppBar(title: Text(feed?.name ?? 'Feed personalizado')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Erro ao carregar feed.')),
        data: (posts) {
          if (posts.isEmpty) {
            return Center(
              child: Text(
                'Nenhuma publicacao nesses topicos ainda.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.muted,
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(customFeedPostsProvider(feedId));
              await ref.read(customFeedPostsProvider(feedId).future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: posts.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) {
                final post = posts[index];
                return FeedPostCard(
                  post: post,
                  onLike: () async {
                    try {
                      await ref
                          .read(feedRepositoryProvider)
                          .toggleLike(post.id, post.likedByMe);
                      ref.invalidate(customFeedPostsProvider(feedId));
                    } catch (_) {}
                  },
                  onComment: () =>
                      context.push('/feed/${post.id}', extra: post),
                  onRepost: () =>
                      context.push('/feed/compose?quote=1', extra: post),
                  onBookmark: () async {
                    await ref
                        .read(feedRepositoryProvider)
                        .toggleBookmark(post.id);
                    ref.invalidate(customFeedPostsProvider(feedId));
                  },
                  onReport: () => showReportDialog(
                    context,
                    ref,
                    reportedUserId: post.userId,
                    targetType: 'post',
                    targetId: post.id,
                    contentSnapshot: post.content,
                  ),
                  onCopyLink: () async {
                    await Clipboard.setData(
                      ClipboardData(text: 'conexa://feed/${post.id}'),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Link da publicacao copiado.'),
                        ),
                      );
                    }
                  },
                  onNotInterested: () async {
                    await ref
                        .read(feedRepositoryProvider)
                        .setNotInterested(post.id, true);
                    ref.invalidate(customFeedPostsProvider(feedId));
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
