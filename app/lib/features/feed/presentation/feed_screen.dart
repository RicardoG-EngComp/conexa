import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/feed_providers.dart';
import '../data/feed_models.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  final _controller = TextEditingController();
  bool _posting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _posting = true);
    try {
      await ref.read(feedRepositoryProvider).createPost(text);
      _controller.clear();
      ref.invalidate(feedProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nao foi possivel publicar.')),
        );
      }
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  Future<void> _toggleLike(FeedPost post) async {
    try {
      await ref
          .read(feedRepositoryProvider)
          .toggleLike(post.id, post.likedByMe);
      ref.invalidate(feedProvider);
    } catch (_) {
      // silencioso no MVP
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final feedAsync = ref.watch(feedProvider);

    final postWidgets = feedAsync.when<List<Widget>>(
      data: (posts) {
        if (posts.isEmpty) {
          return [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Text(
                'Ainda nao ha publicacoes. Comece a conversa!',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppColors.muted,
                ),
              ),
            ),
          ];
        }
        return posts
            .map(
              (post) => _PostCard(
                post: post,
                onLike: () => _toggleLike(post),
                onComment: () => context.push('/feed/${post.id}', extra: post),
              ),
            )
            .toList();
      },
      loading: () => [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
      error: (_, _) => [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
          child: Text('Erro ao carregar o feed.'),
        ),
      ],
    );

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(feedProvider);
            await ref.read(feedProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text('Feed UFV', style: theme.textTheme.displayMedium),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    TextField(
                      controller: _controller,
                      minLines: 2,
                      maxLines: 5,
                      maxLength: 2000,
                      decoration: const InputDecoration(
                        hintText: 'Compartilhe algo com a comunidade UFV...',
                        border: InputBorder.none,
                        counterText: '',
                      ),
                    ),
                    FilledButton(
                      onPressed: _posting ? null : _publish,
                      child: _posting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Publicar'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              ...postWidgets,
            ],
          ),
        ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.post,
    required this.onLike,
    required this.onComment,
  });

  final FeedPost post;
  final VoidCallback onLike;
  final VoidCallback onComment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.teal,
                child: Icon(Icons.person, size: 18, color: Colors.white),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(post.authorName, style: theme.textTheme.titleSmall),
              ),
              Text(
                timeAgo(post.createdAt),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(post.content, style: theme.textTheme.bodyLarge),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              TextButton.icon(
                onPressed: onLike,
                icon: Icon(
                  post.likedByMe ? Icons.favorite : Icons.favorite_border,
                  size: 18,
                  color: post.likedByMe ? AppColors.teal : AppColors.muted,
                ),
                label: Text('${post.likeCount}'),
              ),
              TextButton.icon(
                onPressed: onComment,
                icon: const Icon(
                  Icons.chat_bubble_outline,
                  size: 18,
                  color: AppColors.muted,
                ),
                label: Text('${post.commentCount}'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String timeAgo(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return 'agora';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min';
  if (diff.inHours < 24) return '${diff.inHours} h';
  return '${diff.inDays} d';
}
