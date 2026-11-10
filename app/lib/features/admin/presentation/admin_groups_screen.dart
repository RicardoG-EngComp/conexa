import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../groups/application/group_providers.dart';
import '../../groups/data/group_models.dart';
import '../../groups/presentation/group_common.dart';

class AdminGroupsScreen extends ConsumerWidget {
  const AdminGroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final pendingAsync = ref.watch(pendingGroupsProvider);

    Future<void> review(GroupSummary group, bool approve) async {
      try {
        await ref.read(groupRepositoryProvider).reviewGroup(group.id, approve);
        ref.invalidate(pendingGroupsProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                approve ? 'Grupo aprovado e selo concedido.' : 'Grupo rejeitado.',
              ),
            ),
          );
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nao foi possivel revisar o grupo.')),
          );
        }
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Aprovar grupos')),
      body: pendingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Erro ao carregar grupos.')),
        data: (groups) {
          if (groups.isEmpty) {
            return Center(
              child: Text(
                'Nenhum grupo aguardando aprovação.',
                style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text(
                'Grupos públicos pedindo selo oficial',
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              for (final group in groups)
                Container(
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
                          GroupAvatar(name: group.name, radius: 20),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              group.name,
                              style: theme.textTheme.titleSmall,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '${group.category} · ${group.campus}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                      if (group.description != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          group.description!,
                          style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => review(group, false),
                              icon: const Icon(Icons.close, size: 18),
                              label: const Text('Rejeitar'),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => review(group, true),
                              icon: const Icon(Icons.check, size: 18),
                              label: const Text('Aprovar'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
