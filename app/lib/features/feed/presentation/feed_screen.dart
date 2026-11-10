import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../groups/application/group_providers.dart';
import '../../groups/data/group_models.dart';
import '../../notifications/presentation/notification_bell.dart';
import '../../profile/presentation/incomplete_profile_banner.dart';
import '../../reports/presentation/report_dialog.dart';
import '../application/feed_providers.dart';
import '../data/feed_models.dart';
import 'feed_post_card.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  Future<void> _toggleLike(bool forYou, FeedPost post) async {
    try {
      await ref.read(feedRepositoryProvider).toggleLike(post.id, post.likedByMe);
      ref.invalidate(forYou ? feedForYouProvider : feedConnectionsProvider);
    } catch (_) {
      // silencioso no MVP
    }
  }

  void _report(FeedPost post) {
    showReportDialog(
      context,
      ref,
      reportedUserId: post.userId,
      targetType: 'post',
      targetId: post.id,
      contentSnapshot: post.content,
    );
  }

  void _openPost(FeedPost post) {
    context.push('/feed/${post.id}', extra: post);
  }

  void _repost(FeedPost post) {
    context.push('/feed/compose?quote=1', extra: post);
  }

  void _openComposerMenu(List<UserGroup> groups) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.paper,
      builder: (sheetContext) {
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
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'O que você quer fazer?',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                _ComposerOption(
                  icon: Icons.edit_outlined,
                  title: 'Publicar',
                  subtitle: 'Compartilhar algo no seu perfil.',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    context.push('/feed/compose');
                  },
                ),
                if (groups.isNotEmpty)
                  _ComposerOption(
                    icon: Icons.groups_outlined,
                    title: 'Publicar em grupo',
                    subtitle: 'Escolher um dos seus grupos e um cargo.',
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _pickGroup(groups);
                    },
                  ),
                _ComposerOption(
                  icon: Icons.add_circle_outline,
                  title: 'Criar grupo',
                  subtitle: 'Nome, categoria, campus e visibilidade.',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    context.push('/groups/create');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _pickGroup(List<UserGroup> groups) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.paper,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Text(
                  'Escolha um grupo',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final group in groups)
                ListTile(
                  leading: const Icon(Icons.groups_outlined),
                  title: Text(group.name),
                  subtitle: group.canPostAsGroup
                      ? const Text('Você pode publicar em nome do grupo')
                      : const Text('Você publica como membro'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    context.push('/feed/compose?group=${group.id}');
                  },
                ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final forYou = ref.watch(feedForYouProvider);
    final connections = ref.watch(feedConnectionsProvider);
    final groups = ref.watch(myGroupsProvider).asData?.value ?? const <UserGroup>[];

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Feed UFV', style: theme.textTheme.titleLarge),
          actions: const [NotificationBell()],
          bottom: TabBar(
            indicatorColor: AppColors.teal,
            labelColor: AppColors.ink,
            unselectedLabelColor: AppColors.muted,
            tabs: const [
              Tab(text: 'Para você'),
              Tab(text: 'Conexão'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _openComposerMenu(groups),
          backgroundColor: AppColors.teal,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: const Icon(Icons.add),
        ),
        body: TabBarView(
          children: [
            _FeedTab(
              feed: forYou,
              forYou: true,
              onLike: (post) => _toggleLike(true, post),
              onComment: _openPost,
              onRepost: _repost,
              onReport: _report,
            ),
            _FeedTab(
              feed: connections,
              forYou: false,
              onLike: (post) => _toggleLike(false, post),
              onComment: _openPost,
              onRepost: _repost,
              onReport: _report,
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedTab extends ConsumerWidget {
  const _FeedTab({
    required this.feed,
    required this.forYou,
    required this.onLike,
    required this.onComment,
    required this.onRepost,
    required this.onReport,
  });

  final AsyncValue<List<FeedPost>> feed;
  final bool forYou;
  final void Function(FeedPost post) onLike;
  final void Function(FeedPost post) onComment;
  final void Function(FeedPost post) onRepost;
  final void Function(FeedPost post) onReport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final provider = forYou ? feedForYouProvider : feedConnectionsProvider;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(provider);
        await ref.read(provider.future);
      },
      child: feed.when(
        data: (posts) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              100,
            ),
            children: [
              if (forYou) ...[
                const IncompleteProfileBanner(),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Ordenado pelo seu curso, campus, interesses e recência.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              if (posts.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: Text(
                    forYou
                        ? 'Nada por aqui ainda. Publique algo ou siga grupos.'
                        : 'Suas conexões e grupos seguidos aparecem aqui.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                ),
              for (final post in posts) ...[
                FeedPostCard(
                  post: post,
                  showSource: !forYou,
                  showRelevance: forYou,
                  onLike: () => onLike(post),
                  onComment: () => onComment(post),
                  onRepost: () => onRepost(post),
                  onReport: () => onReport(post),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Erro ao carregar o feed.')),
      ),
    );
  }
}

class _ComposerOption extends StatelessWidget {
  const _ComposerOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        height: 42,
        width: 42,
        decoration: BoxDecoration(
          color: AppColors.teal.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Icon(icon, color: AppColors.teal),
      ),
      title: Text(title, style: theme.textTheme.titleSmall),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
      ),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }
}
