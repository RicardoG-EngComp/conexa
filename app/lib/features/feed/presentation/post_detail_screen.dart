import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/moderation_errors.dart';
import '../../../core/errors/moderation_ui.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/time_ago.dart';
import '../../groups/application/group_providers.dart';
import '../application/feed_providers.dart';
import '../data/feed_models.dart';
import 'feed_post_card.dart';

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
  String? _replyToId;
  String? _replyToName;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startReply(FeedComment comment) {
    setState(() {
      _replyToId = comment.id;
      _replyToName = comment.authorName;
    });
    FocusScope.of(context).requestFocus();
  }

  void _clearReply() {
    setState(() {
      _replyToId = null;
      _replyToName = null;
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(feedRepositoryProvider)
          .addComment(widget.postId, text, parentId: _replyToId);
      _controller.clear();
      _clearReply();
      ref.invalidate(commentsProvider(widget.postId));
      ref.invalidate(feedForYouProvider);
      ref.invalidate(feedConnectionsProvider);
    } catch (error) {
      if (mounted) {
        if (needsGuidelinesAcceptance(error)) {
          await showGuidelinesConsentDialog(context);
        } else {
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
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _toggleLike() async {
    final post = widget.post;
    if (post == null) return;
    try {
      await ref.read(feedRepositoryProvider).toggleLike(post.id, post.likedByMe);
      ref.invalidate(feedForYouProvider);
      ref.invalidate(feedConnectionsProvider);
    } catch (_) {}
  }

  Future<void> _moderatePost(String action) async {
    final post = widget.post;
    if (post == null || post.groupId == null) return;

    if (action == 'delete') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Apagar publicação?'),
          content: const Text(
            'A publicação e as respostas dela somem do grupo. '
            'Esta ação não pode ser desfeita.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Apagar'),
            ),
          ],
        ),
      );
      if (confirm != true || !mounted) return;
    }

    try {
      await ref.read(groupRepositoryProvider).moderatePost(widget.postId, action);
      ref.invalidate(feedForYouProvider);
      ref.invalidate(feedConnectionsProvider);
      ref.invalidate(commentsProvider(widget.postId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              action == 'hide'
                  ? 'Publicação ocultada.'
                  : 'Publicação apagada.',
            ),
          ),
        );
        context.pop();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nao foi possivel moderar.')),
        );
      }
    }
  }

  Future<void> _deleteComment(FeedComment comment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apagar resposta?'),
        content: Text('A resposta de ${comment.authorName} será apagada.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    try {
      await ref.read(groupRepositoryProvider).moderateComment(comment.id, 'delete');
      ref.invalidate(commentsProvider(widget.postId));
      ref.invalidate(feedForYouProvider);
      ref.invalidate(feedConnectionsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Resposta apagada.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nao foi possivel moderar.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final commentsAsync = ref.watch(commentsProvider(widget.postId));
    final post = widget.post;

    final isGroupPost = post != null && post.groupId != null;
    final canModerate = isGroupPost
        ? (ref.watch(groupModeratorFlagProvider(post.groupId!)).asData?.value
              ?? false)
        : false;

    return Scaffold(
      appBar: AppBar(title: const Text('Publicacao')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                if (post != null) ...[
                  FeedPostCard(
                    post: post,
                    detail: true,
                    onLike: _toggleLike,
                    onRepost: () =>
                        context.push('/feed/compose?quote=1', extra: post),
                    onHide: canModerate
                        ? () => _moderatePost('hide')
                        : null,
                    onDelete: canModerate
                        ? () => _moderatePost('delete')
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.lg),
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
                    final childrenOf = <String?, List<FeedComment>>{};
                    for (final c in comments) {
                      childrenOf.putIfAbsent(c.parentId, () => []).add(c);
                    }
                    final roots = childrenOf[null] ?? const <FeedComment>[];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Respostas', style: theme.textTheme.headlineMedium),
                        const SizedBox(height: AppSpacing.md),
                        for (final root in roots)
                          _CommentNode(
                            comment: root,
                            depth: 0,
                            childrenOf: childrenOf,
                            onReply: _startReply,
                            canModerate: canModerate,
                            onDelete: _deleteComment,
                          ),
                      ],
                    );
                  },
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (_, _) => const Text('Erro ao carregar comentarios.'),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              decoration: const BoxDecoration(
                color: AppColors.paper,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_replyToName != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: Row(
                        children: [
                          const Icon(Icons.subdirectory_arrow_right, size: 14),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Respondendo a $_replyToName',
                              style: theme.textTheme.labelSmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          InkWell(
                            onTap: _clearReply,
                            child: const Icon(Icons.close, size: 16),
                          ),
                        ],
                      ),
                    ),
                  Row(
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentNode extends StatefulWidget {
  const _CommentNode({
    required this.comment,
    required this.depth,
    required this.childrenOf,
    required this.onReply,
    this.canModerate = false,
    this.onDelete,
  });

  final FeedComment comment;
  final int depth;
  final Map<String?, List<FeedComment>> childrenOf;
  final void Function(FeedComment comment) onReply;
  final bool canModerate;
  final void Function(FeedComment comment)? onDelete;

  @override
  State<_CommentNode> createState() => _CommentNodeState();
}

class _CommentNodeState extends State<_CommentNode> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final comment = widget.comment;
    final children = widget.childrenOf[comment.id] ?? const <FeedComment>[];

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const CircleAvatar(
              radius: 13,
              backgroundColor: AppColors.border,
              child: Icon(Icons.person, size: 16, color: AppColors.muted),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(comment.authorName, style: theme.textTheme.titleSmall),
            ),
            Text(
              timeAgo(comment.createdAt),
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
            ),
            if (widget.canModerate && widget.onDelete != null)
              IconButton(
                icon: const Icon(Icons.more_horiz, size: 16),
                tooltip: 'Moderar resposta',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => widget.onDelete!(comment),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          comment.content,
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
        ),
        Row(
          children: [
            if (widget.depth < 3)
              TextButton(
                onPressed: () => widget.onReply(comment),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.muted,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                ),
                child: const Text('Responder'),
              ),
            if (children.isNotEmpty && !_expanded)
              TextButton.icon(
                onPressed: () => setState(() => _expanded = true),
                icon: const Icon(Icons.subdirectory_arrow_right, size: 16),
                label: Text('Ver ${children.length} resposta(s)'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.teal,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                ),
              ),
            if (children.isNotEmpty && _expanded)
              TextButton(
                onPressed: () => setState(() => _expanded = false),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.muted,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                ),
                child: const Text('Ocultar respostas'),
              ),
          ],
        ),
        if (_expanded)
          for (final child in children)
            _CommentNode(
              comment: child,
              depth: widget.depth + 1,
              childrenOf: widget.childrenOf,
              onReply: widget.onReply,
              canModerate: widget.canModerate,
              onDelete: widget.onDelete,
            ),
      ],
    );

    if (widget.depth == 0) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: body,
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      padding: const EdgeInsets.only(left: AppSpacing.md),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: AppColors.border, width: 2)),
      ),
      child: body,
    );
  }
}
