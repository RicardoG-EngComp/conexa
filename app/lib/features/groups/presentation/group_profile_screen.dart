import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/group_providers.dart';
import '../data/group_models.dart';
import 'group_common.dart';
import 'group_invites_tab.dart';
import 'group_members_tab.dart';
import 'group_roles_tab.dart';

class GroupProfileScreen extends ConsumerStatefulWidget {
  const GroupProfileScreen({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<GroupProfileScreen> createState() => _GroupProfileScreenState();
}

class _GroupProfileScreenState extends ConsumerState<GroupProfileScreen> {
  void _refresh() {
    ref.invalidate(groupDetailProvider(widget.groupId));
    ref.invalidate(groupMembersProvider(widget.groupId));
    ref.invalidate(groupRolesProvider(widget.groupId));
    ref.invalidate(groupInvitesProvider(widget.groupId));
    ref.invalidate(groupFollowersProvider(widget.groupId));
    ref.invalidate(myGroupsProvider);
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    try {
      await action();
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(success)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nao foi possivel concluir.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(groupDetailProvider(widget.groupId));

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Voltar',
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/groups');
              }
            },
          ),
          title: const Text('Grupo'),
          actions: [
            detailAsync.maybeWhen(
              data: (d) => d != null && d.canManageGroup
                  ? IconButton(
                      icon: const Icon(Icons.settings_outlined),
                      tooltip: 'Gerenciar grupo',
                      onPressed: () =>
                          context.push('/groups/${widget.groupId}/manage'),
                    )
                  : const SizedBox.shrink(),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
        body: detailAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const Center(child: Text('Erro ao carregar grupo.')),
          data: (detail) {
            if (detail == null) {
              return const Center(child: Text('Grupo indisponivel.'));
            }
            final members = ref.watch(groupMembersProvider(widget.groupId));
            final roles = ref.watch(groupRolesProvider(widget.groupId));
            final invites = ref.watch(groupInvitesProvider(widget.groupId));
            final followers = ref.watch(groupFollowersProvider(widget.groupId));

            return Column(
              children: [
                _Header(
                  detail: detail,
                  onJoin: () => _run(
                    () => ref.read(groupRepositoryProvider).joinGroup(widget.groupId),
                    'Voce entrou no grupo.',
                  ),
                  onLeave: () => _run(
                    () => ref.read(groupRepositoryProvider).leaveGroup(widget.groupId),
                    'Voce saiu do grupo.',
                  ),
                  onFollow: () => _run(
                    () => ref.read(groupRepositoryProvider).followGroup(widget.groupId),
                    'Voce seguiu o grupo.',
                  ),
                  onUnfollow: () => _run(
                    () => ref.read(groupRepositoryProvider).unfollowGroup(widget.groupId),
                    'Voce deixou de seguir o grupo.',
                  ),
                  onRequestPublic: () => _run(
                    () => ref.read(groupRepositoryProvider).requestPublicGroup(widget.groupId),
                    'Pedido de selo oficial enviado para a moderacao.',
                  ),
                ),
                TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  indicatorColor: AppColors.teal,
                  labelColor: AppColors.ink,
                  unselectedLabelColor: AppColors.muted,
                  tabs: const [
                    Tab(text: 'Membros'),
                    Tab(text: 'Cargos'),
                    Tab(text: 'Seguidores'),
                    Tab(text: 'Convites'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      GroupMembersTab(
                        groupId: widget.groupId,
                        detail: detail,
                        members: members.asData?.value ?? const [],
                        roles: roles.asData?.value ?? const [],
                        onChanged: _refresh,
                      ),
                      GroupRolesTab(
                        groupId: widget.groupId,
                        detail: detail,
                        roles: roles.asData?.value ?? const [],
                        onChanged: _refresh,
                      ),
                      _FollowersTab(
                        detail: detail,
                        followers: followers.asData?.value ?? const [],
                      ),
                      GroupInvitesTab(
                        groupId: widget.groupId,
                        detail: detail,
                        invites: invites.asData?.value ?? const [],
                        onChanged: _refresh,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.detail,
    required this.onJoin,
    required this.onLeave,
    required this.onFollow,
    required this.onUnfollow,
    required this.onRequestPublic,
  });

  final GroupDetail detail;
  final VoidCallback onJoin;
  final VoidCallback onLeave;
  final VoidCallback onFollow;
  final VoidCallback onUnfollow;
  final VoidCallback onRequestPublic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meId = Supabase.instance.client.auth.currentUser?.id;
    final isOwner = detail.ownerId == meId;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GroupAvatar(name: detail.name, radius: 30),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(detail.name, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        if (detail.isOfficial) const GroupSealChip(),
                        _MiniTag(label: detail.category),
                        _MiniTag(label: detail.campus),
                        _MiniTag(
                          label: detail.visibility == 'public'
                              ? 'Público'
                              : 'Privado',
                          icon: detail.visibility == 'public'
                              ? Icons.public
                              : Icons.lock_outline,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (detail.description != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              detail.description!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.muted,
                height: 1.45,
              ),
            ),
          ],
          if (detail.pendingPublic) ...[
            const SizedBox(height: AppSpacing.sm),
            const _InfoLine(
              icon: Icons.hourglass_top,
              text: 'Aguardando aprovação da moderação para receber o selo.',
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _Stat(label: 'Membros', value: '${detail.memberCount}'),
              const SizedBox(width: AppSpacing.lg),
              _Stat(label: 'Seguidores', value: '${detail.followerCount}'),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              if (detail.isMember)
                isOwner
                    ? OutlinedButton.icon(
                        onPressed: null,
                        icon: const Icon(Icons.star_outline, size: 18),
                        label: const Text('Dono'),
                      )
                    : OutlinedButton.icon(
                        onPressed: onLeave,
                        icon: const Icon(Icons.logout, size: 18),
                        label: const Text('Sair do grupo'),
                      )
              else if (detail.isPublicApproved)
                FilledButton.icon(
                  onPressed: onJoin,
                  icon: const Icon(Icons.login, size: 18),
                  label: const Text('Entrar'),
                ),
              if (detail.isPublicApproved)
                OutlinedButton.icon(
                  onPressed: detail.isFollowing ? onUnfollow : onFollow,
                  icon: Icon(
                    detail.isFollowing
                        ? Icons.notifications_active_outlined
                        : Icons.notifications_none,
                    size: 18,
                  ),
                  label: Text(detail.isFollowing ? 'Seguindo' : 'Seguir'),
                ),
              if (detail.canManageGroup && detail.visibility == 'private')
                OutlinedButton.icon(
                  onPressed: onRequestPublic,
                  icon: const Icon(Icons.verified_outlined, size: 18),
                  label: const Text('Pedir selo oficial'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FollowersTab extends StatelessWidget {
  const _FollowersTab({required this.detail, required this.followers});

  final GroupDetail detail;
  final List<String> followers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        if (!detail.isMember)
          Text(
            'Os seguidores ficam visíveis apenas para membros.',
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
          )
        else if (followers.isEmpty)
          Text(
            'Ninguém segue este grupo ainda.',
            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          )
        else
          for (final name in followers)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: GroupAvatar(name: name, radius: 17),
              title: Text(name, style: theme.textTheme.titleSmall),
              subtitle: Text(
                'Seguidor',
                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
              ),
            ),
      ],
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: AppColors.muted),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted)),
      ],
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.teal),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
          ),
        ),
      ],
    );
  }
}
