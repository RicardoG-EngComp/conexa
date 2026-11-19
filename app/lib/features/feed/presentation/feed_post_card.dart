import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/media/media_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/ribbon_icon.dart';
import '../../../core/utils/time_ago.dart';
import '../data/feed_models.dart';
import 'feed_media_view.dart';
import 'post_poll_view.dart';

class FeedPostCard extends StatelessWidget {
  const FeedPostCard({
    super.key,
    required this.post,
    this.onLike,
    this.onComment,
    this.onRepost,
    this.onReport,
    this.onHide,
    this.onDelete,
    this.onBookmark,
    this.onEdit,
    this.onPin,
    this.onNotInterested,
    this.onCopyLink,
    this.detail = false,
    this.showSource = false,
    this.showRelevance = false,
  });

  final FeedPost post;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onRepost;
  final VoidCallback? onReport;
  final VoidCallback? onHide;
  final VoidCallback? onDelete;
  final VoidCallback? onBookmark;
  final VoidCallback? onEdit;
  final VoidCallback? onPin;
  final VoidCallback? onNotInterested;
  final VoidCallback? onCopyLink;
  final bool detail;
  final bool showSource;
  final bool showRelevance;

  void _showTopics(BuildContext context, List<FeedTopic> topics) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.paper,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tópicos da publicação',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: topics
                      .map((topic) => _TopicChip(topic: topic))
                      .toList(),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayName = post.postedAsGroup
        ? (post.groupName ?? post.authorName)
        : post.authorName;
    final subtitle = post.postedAsGroup
        ? 'Em nome do grupo · por ${post.authorName}'
        : (post.authorName == displayName ? null : post.authorName);

    final card = Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.paper,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showSource && post.source != null) ...[
            _SourceChip(source: post.source!),
            const SizedBox(height: AppSpacing.sm),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AuthorAvatar(path: post.avatarPath, name: displayName),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        if (post.postedAsGroup && post.groupOfficial) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.verified, size: 15, color: AppColors.teal),
                        ],
                        const SizedBox(width: 5),
                        Text(
                          '·',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          timeAgo(post.createdAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                        if (post.pinnedAt != null) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.push_pin, size: 14, color: AppColors.teal),
                        ],
                        if (post.editedAt != null) ...[
                          const SizedBox(width: 4),
                          Text(
                            'editado',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onReport != null ||
                  onHide != null ||
                  onDelete != null ||
                  onBookmark != null ||
                  onEdit != null ||
                  onPin != null ||
                  onNotInterested != null ||
                  onCopyLink != null)
                PopupMenuButton<String>(
                  tooltip: 'Mais opções',
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.more_horiz, size: 20),
                  onSelected: (value) {
                    switch (value) {
                      case 'report':
                        onReport?.call();
                      case 'hide':
                        onHide?.call();
                      case 'delete':
                        onDelete?.call();
                      case 'bookmark':
                        onBookmark?.call();
                      case 'edit':
                        onEdit?.call();
                      case 'pin':
                        onPin?.call();
                      case 'not_interested':
                        onNotInterested?.call();
                      case 'copy_link':
                        onCopyLink?.call();
                    }
                  },
                  itemBuilder: (_) => [
                    if (onNotInterested != null)
                      const PopupMenuItem<String>(
                        value: 'not_interested',
                        child: Text('Nao tenho interesse'),
                      ),
                    if (onCopyLink != null)
                      const PopupMenuItem<String>(
                        value: 'copy_link',
                        child: Text('Copiar link da publicacao'),
                      ),
                    if (onBookmark != null)
                      PopupMenuItem<String>(
                        value: 'bookmark',
                        child: Text(
                          post.bookmarked ? 'Remover dos salvos' : 'Salvar',
                        ),
                      ),
                    if (onEdit != null)
                      const PopupMenuItem<String>(
                        value: 'edit',
                        child: Text('Editar publicacao'),
                      ),
                    if (onPin != null)
                      PopupMenuItem<String>(
                        value: 'pin',
                        child: Text(
                          post.pinnedAt == null
                              ? 'Fixar no perfil'
                              : 'Desafixar do perfil',
                        ),
                      ),
                    if (onReport != null)
                      const PopupMenuItem<String>(
                        value: 'report',
                        child: Text('Denunciar publicação'),
                      ),
                    if (onHide != null)
                      const PopupMenuItem<String>(
                        value: 'hide',
                        child: Text('Ocultar publicação'),
                      ),
                    if (onDelete != null)
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: Text(
                          'Apagar publicação',
                          style: TextStyle(color: AppColors.danger),
                        ),
                      ),
                  ],
                ),
            ],
          ),
          if (post.groupName != null && !post.postedAsGroup) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(Icons.groups_outlined, size: 14, color: AppColors.muted),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    'no grupo ${post.groupName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (post.roleNameSnapshot != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _RoleChip(name: post.roleNameSnapshot!, current: post.roleCurrent),
          ],
          const SizedBox(height: AppSpacing.sm),
          if (post.wasRepost) ...[
            Row(
              children: [
                Icon(Icons.repeat, size: 14, color: AppColors.muted),
                const SizedBox(width: 5),
                Text(
                  'Republicou',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          if (post.content.isNotEmpty)
            Text(
              post.content,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
            ),
          if (post.quoted != null) ...[
            const SizedBox(height: AppSpacing.md),
            _QuotedCard(quoted: post.quoted!),
          ],
          if (post.repostOf != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _QuotedCard(quoted: post.repostOf!),
          ],
          FeedMediaView(media: post.media),
          if (post.poll != null) PostPollView(poll: post.poll!),
          if (post.mentions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final mention in post.mentions)
                  Text(
                    '@${mention.displayName}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.teal,
                    ),
                  ),
              ],
            ),
          ],
          if (post.topics.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Tooltip(
              message: 'Segure para ver os tópicos',
              child: Semantics(
                label: 'Tópicos da publicação. Segure para ver a lista.',
                button: true,
                child: GestureDetector(
                  onLongPress: () => _showTopics(context, post.topics),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.teal.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(
                        color: AppColors.teal.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.sell_outlined,
                          size: 14,
                          color: AppColors.teal,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${post.topics.length}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.teal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
          if (showRelevance &&
              (post.courseMatch || post.campusMatch || post.interestMatch)) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                if (post.courseMatch) const _RelevanceChip(label: 'Seu curso'),
                if (post.campusMatch) const _RelevanceChip(label: 'Seu campus'),
                if (post.interestMatch)
                  const _RelevanceChip(label: 'Seu interesse'),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _PostAction(
                  icon: 'comment',
                  label: '${post.commentCount}',
                  tooltip: 'Responder',
                  onTap: onComment,
                ),
              ),
              Expanded(
                child: _PostAction(
                  icon: 'repost',
                  tooltip: 'Republicar',
                  onTap: onRepost,
                ),
              ),
              Expanded(
                child: _PostAction(
                  icon: 'heart',
                  label: '${post.likeCount}',
                  color: post.likedByMe ? AppColors.teal : AppColors.muted,
                  tooltip: post.likedByMe ? 'Descurtir' : 'Curtir',
                  onTap: onLike,
                ),
              ),
              Expanded(
                child: _PostAction(
                  icon: 'bookmark',
                  color: post.bookmarked ? AppColors.teal : AppColors.muted,
                  tooltip: post.bookmarked ? 'Remover dos salvos' : 'Salvar',
                  onTap: onBookmark,
                ),
              ),
              Expanded(
                child: _PostAction(
                  icon: 'share',
                  tooltip: 'Compartilhar',
                  onTap: onCopyLink,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (detail) return card;
    return InkWell(onTap: onComment, child: card);
  }
}

class _AuthorAvatar extends ConsumerWidget {
  const _AuthorAvatar({required this.path, required this.name});

  final String? path;
  final String name;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (path == null || path!.isEmpty) {
      return CircleAvatar(
        radius: 19,
        backgroundColor: AppColors.teal,
        child: Text(
          _initials,
          style: TextStyle(color: AppColors.onPrimary, fontSize: 13),
        ),
      );
    }
    return ClipOval(
      child: SizedBox(
        width: 38,
        height: 38,
        child: MediaImage(path: path!, width: 38, height: 38),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.name, required this.current});

  final String name;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = current ? AppColors.teal : const Color(0xFF8A5A00);
    final icon = current ? Icons.verified_user_outlined : Icons.history;
    final label = current ? name : '$name · cargo à época';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuotedCard extends StatelessWidget {
  const _QuotedCard({required this.quoted});

  final FeedQuotedPost quoted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: quoted.available
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.format_quote, size: 16, color: AppColors.teal),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        quoted.authorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  quoted.content,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.muted,
                    height: 1.45,
                  ),
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_outline, size: 18, color: AppColors.muted),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Conteúdo indisponível',
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Quem publicou restringiu a visualização ou o conteúdo '
                        'foi removido.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _TopicChip extends StatelessWidget {
  const _TopicChip({required this.topic});

  final FeedTopic topic;

  Color get _color {
    if (topic.isCourse) return AppColors.teal;
    if (topic.isCampus) return AppColors.muted;
    return AppColors.success;
  }

  IconData get _icon {
    if (topic.isCourse) return Icons.school_outlined;
    if (topic.isCampus) return Icons.place_outlined;
    return Icons.event_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            topic.label,
            style: theme.textTheme.labelSmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({required this.source});

  final String source;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, icon) = switch (source) {
      'connection' => ('Conexão', Icons.people_outline),
      'group_followed' => ('Grupo seguido', Icons.groups_outlined),
      _ => ('Você', Icons.person_outline),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.muted),
        const SizedBox(width: 5),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(color: AppColors.muted),
        ),
      ],
    );
  }
}

class _RelevanceChip extends StatelessWidget {
  const _RelevanceChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.teal.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(color: AppColors.teal),
      ),
    );
  }
}

class _PostAction extends StatelessWidget {
  const _PostAction({
    required this.icon,
    this.label,
    this.color,
    this.tooltip,
    this.onTap,
  });

  final String icon;
  final String? label;
  final Color? color;
  final String? tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppColors.muted;
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        RibbonIcon(icon, size: 19, color: tint),
        if (label != null && label!.isNotEmpty) ...[
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: tint),
            ),
          ),
        ],
      ],
    );
    final action = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: child,
      ),
    );
    if (tooltip == null) return action;
    return Tooltip(message: tooltip!, child: action);
  }
}
