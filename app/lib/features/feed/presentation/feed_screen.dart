import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/time_ago.dart';
import '../../chat/application/chat_providers.dart';
import '../../profile/application/profile_providers.dart';
import '../../reports/presentation/report_dialog.dart';
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
                onMessage: () async {
                  final id = await ref
                      .read(chatRepositoryProvider)
                      .startConversation(post.userId);
                  if (context.mounted) context.push('/chats/$id');
                },
                onReport: () => showReportDialog(
                  context,
                  ref,
                  reportedUserId: post.userId,
                  targetType: 'post',
                  targetId: post.id,
                  contentSnapshot: post.content,
                ),
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
    required this.onMessage,
    required this.onReport,
  });

  final FeedPost post;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onMessage;
  final VoidCallback onReport;

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
              InkWell(
                onTap: () => context.push('/profile/${post.userId}'),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _AuthorAvatar(path: post.avatarPath),
                    const SizedBox(width: AppSpacing.sm),
                    Text(post.authorName, style: theme.textTheme.titleSmall),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                timeAgo(post.createdAt),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.muted,
                ),
              ),
              if (Supabase.instance.client.auth.currentUser?.id != post.userId)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (value) {
                    if (value == 'report') onReport();
                    if (value == 'message') onMessage();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'message', child: Text('Mensagem')),
                    PopupMenuItem(value: 'report', child: Text('Denunciar')),
                  ],
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

class _AuthorAvatar extends ConsumerWidget {
  const _AuthorAvatar({required this.path});

  final String? path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const fallback = CircleAvatar(
      radius: 16,
      backgroundColor: AppColors.teal,
      child: Icon(Icons.person, size: 18, color: Colors.white),
    );
    if (path == null || path!.isEmpty) return fallback;
    final url = ref.watch(signedUrlProvider(path!));
    final value = url.asData?.value;
    if (value == null) return fallback;
    return CircleAvatar(radius: 16, backgroundImage: NetworkImage(value));
  }
}
