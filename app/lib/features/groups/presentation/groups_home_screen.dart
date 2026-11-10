import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../notifications/presentation/notification_bell.dart';
import '../application/group_providers.dart';
import '../data/group_models.dart';
import 'group_common.dart';

class GroupsHomeScreen extends ConsumerWidget {
  const GroupsHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final groupsAsync = ref.watch(myGroupsProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Grupos',
                      style: theme.textTheme.displayMedium,
                    ),
                  ),
                  const NotificationBell(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.go('/discover'),
                      icon: const Icon(Icons.travel_explore, size: 18),
                      label: const Text('Descobrir grupos'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showInviteDialog(context),
                      icon: const Icon(Icons.key_outlined, size: 18),
                      label: const Text('Tenho um convite'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(myGroupsProvider);
                  await ref.read(myGroupsProvider.future);
                },
                child: groupsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, _) => const Center(
                    child: Text('Erro ao carregar seus grupos.'),
                  ),
                  data: (groups) {
                    if (groups.isEmpty) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        children: [
                          const SizedBox(height: AppSpacing.xl),
                          Icon(
                            Icons.groups_outlined,
                            size: 48,
                            color: AppColors.muted.withValues(alpha: 0.6),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'Você ainda não participa de grupos.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Crie um grupo ou entre com um convite para começar.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      );
                    }
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.sm,
                        AppSpacing.lg,
                        AppSpacing.xxl,
                      ),
                      children: [
                        for (final group in groups) ...[
                          _GroupTile(group: group),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/groups/create'),
        backgroundColor: AppColors.teal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Criar grupo'),
      ),
    );
  }

  Future<void> _showInviteDialog(BuildContext context) async {
    final controller = TextEditingController();
    final token = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tenho um convite'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cole o link do convite recebido ou o código.',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Link ou código do convite',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final input = controller.text.trim();
              final match = RegExp(r'/join/([A-Za-z0-9]+)').firstMatch(input);
              final value = match?.group(1) ?? input;
              if (value.isEmpty) return;
              Navigator.pop(ctx, value);
            },
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (token == null || token.isEmpty || !context.mounted) return;
    context.push('/join/$token');
  }
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({required this.group});

  final UserGroup group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => context.push('/groups/${group.id}'),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            GroupAvatar(name: group.name, radius: 22),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          group.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      if (group.isOfficial) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.verified,
                          size: 15,
                          color: AppColors.teal,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: group.roles
                        .take(3)
                        .map((r) => RoleTag(label: r.name))
                        .toList(),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}
