import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/moderation_errors.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/time_ago.dart';
import '../application/feed_providers.dart';
import '../data/feed_models.dart';

class PostDetailScreen extends ConsumerStatefulWidget {
  const PostDetailScreen({super.key, required this.postId, this.post});

  final String postId;
  final FeedPost? post;

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref.read(feedRepositoryProvider).addComment(widget.postId, text);
      _controller.clear();
      ref.invalidate(commentsProvider(widget.postId));
      ref.invalidate(feedProvider);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              friendlyModerationError(
                error,
                fallback: 'Nao foi possivel comentar.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final commentsAsync = ref.watch(commentsProvider(widget.postId));
    final post = widget.post;

    return Scaffold(
      appBar: AppBar(title: const Text('Publicacao')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  if (post != null) ...[
                    Text(post.authorName, style: theme.textTheme.titleSmall),
                    Text(
                      timeAgo(post.createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(post.content, style: theme.textTheme.bodyLarge),
                    const Divider(height: AppSpacing.xl),
                  ],
                  commentsAsync.when(
                    data: (comments) {
                      if (comments.isEmpty) {
                        return Text(
                          'Seja o primeiro a comentar.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.muted,
                          ),
                        );
                      }
                      return Column(
                        children: comments
                            .map(
                              (c) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const CircleAvatar(
                                  radius: 14,
                                  backgroundColor: AppColors.border,
                                  child: Icon(Icons.person, size: 16),
                                ),
                                title: Text(c.authorName),
                                subtitle: Text(c.content),
                                trailing: Text(
                                  timeAgo(c.createdAt),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.muted,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      );
                    },
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.lg),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (_, _) =>
                        const Text('Erro ao carregar comentarios.'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Escreva um comentario...',
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
