import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../connections/application/connection_providers.dart';
import '../../connections/data/connection_models.dart';
import '../application/group_providers.dart';
import '../data/group_models.dart';
import 'group_common.dart';

class GroupInvitesTab extends ConsumerWidget {
  const GroupInvitesTab({
    super.key,
    required this.groupId,
    required this.detail,
    required this.invites,
    required this.onChanged,
  });

  final String groupId;
  final GroupDetail detail;
  final List<GroupInvite> invites;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final repo = ref.read(groupRepositoryProvider);

    if (!detail.canManageInvites) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            'Só quem gerencia convites vê esta lista.',
            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          ),
        ),
      );
    }

    Future<void> inviteConnection() async {
      final recipient = await showModalBottomSheet<ConnectionEntry>(
        context: context,
        showDragHandle: true,
        backgroundColor: AppColors.paper,
        builder: (_) => const _ConnectionsPicker(),
      );
      if (recipient == null || !context.mounted) return;

      try {
        await repo.inviteConnection(groupId, recipient.userId);
        onChanged();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Convite enviado para ${recipient.displayName}.'),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_inviteError(e.toString()))),
          );
        }
      }
    }

    Future<void> revokeInvite(GroupInvite invite) async {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Revogar convite?'),
          content: const Text('O convite deixa de valer imediatamente.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Revogar'),
            ),
          ],
        ),
      );
      if (confirm != true || !context.mounted) return;
      try {
        await repo.revokeInvite(invite.id);
        onChanged();
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Não foi possível revogar o convite.'),
            ),
          );
        }
      }
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Container(
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
                  const Icon(Icons.mail_outline, size: 18, color: AppColors.teal),
                  const SizedBox(width: 6),
                  Text(
                    'Convite dentro do app',
                    style: theme.textTheme.titleSmall,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'A pessoa convidada recebe uma notificação e vê o convite em '
                'Grupos → Convites recebidos. Nenhum link é gerado.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.muted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                onPressed: inviteConnection,
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Convidar conexão'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (invites.isEmpty)
          Text(
            'Nenhum convite enviado ainda.',
            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          ),
        for (final invite in invites)
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InviteStatusChip(status: invite.status),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        invite.targetName == null
                            ? 'Convite por link (legado)'
                            : 'Para: ${invite.targetName}',
                        style: theme.textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${invite.usedCount} de ${invite.maxUses} usos · '
                        'validade ${formatDate(invite.expiresAt)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (invite.status == GroupInviteStatus.active)
                  TextButton(
                    onPressed: () => revokeInvite(invite),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.danger,
                    ),
                    child: const Text('Revogar'),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  String _inviteError(String raw) {
    if (raw.contains('sem_conexao')) {
      return 'Só é possível convidar conexões aceitas.';
    }
    if (raw.contains('ja_e_membro')) return 'Essa pessoa já é membro.';
    if (raw.contains('destinatario_inativo')) {
      return 'A conta da pessoa não está ativa.';
    }
    if (raw.contains('forbidden')) return 'Você não pode convidar neste grupo.';
    return 'Não foi possível enviar o convite.';
  }
}

class _ConnectionsPicker extends ConsumerWidget {
  const _ConnectionsPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final connections = ref.watch(connectionsProvider);

    return SafeArea(
      child: SizedBox(
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(
                'Convidar uma conexão',
                style: theme.textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(
                'Só conexões aceitas podem receber convites por aqui.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.muted,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: connections.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => const Center(
                  child: Text('Erro ao carregar conexões.'),
                ),
                data: (data) {
                  if (data.accepted.isEmpty) {
                    return Center(
                      child: Text(
                        'Você ainda não tem conexões aceitas.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    children: [
                      for (final entry in data.accepted)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(
                            radius: 18,
                            backgroundColor: AppColors.border,
                            child: Icon(
                              Icons.person,
                              size: 18,
                              color: AppColors.muted,
                            ),
                          ),
                          title: Text(
                            entry.displayName,
                            style: theme.textTheme.titleSmall,
                          ),
                          onTap: () => Navigator.pop(context, entry),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
