import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../reports/presentation/report_dialog.dart';
import '../application/feed_providers.dart';
import 'feed_post_card.dart';

class SavedPostsScreen extends ConsumerWidget {
  const SavedPostsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(savedPostsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Salvos')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Erro ao carregar salvos.')),
        data: (posts) {
          if (posts.isEmpty) {
            return Center(
              child: Text(
                'Nenhuma publicacao salva.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppColors.muted,
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(savedPostsProvider);
              await ref.read(savedPostsProvider.future);
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
                      ref.invalidate(savedPostsProvider);
                      ref.invalidate(feedForYouProvider);
                      ref.invalidate(feedConnectionsProvider);
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
                    ref.invalidate(savedPostsProvider);
                    ref.invalidate(feedForYouProvider);
                    ref.invalidate(feedConnectionsProvider);
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
                    ref.invalidate(savedPostsProvider);
                    ref.invalidate(feedForYouProvider);
                    ref.invalidate(feedConnectionsProvider);
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
