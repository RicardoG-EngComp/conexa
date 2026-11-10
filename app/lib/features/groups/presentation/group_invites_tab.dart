import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
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

    Future<void> createInvite() async {
      final draft = await showDialog<({int hours, int maxUses})>(
        context: context,
        builder: (ctx) {
          var hours = 168;
          var maxUses = 1;
          return StatefulBuilder(
            builder: (context, setState) => AlertDialog(
              title: const Text('Criar convite'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: hours,
                    decoration: const InputDecoration(labelText: 'Validade'),
                    items: const [
                      DropdownMenuItem<int>(value: 24, child: Text('24 horas')),
                      DropdownMenuItem<int>(value: 168, child: Text('7 dias')),
                      DropdownMenuItem<int>(value: 720, child: Text('30 dias')),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => hours = value);
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  DropdownButtonFormField<int>(
                    initialValue: maxUses,
                    decoration: const InputDecoration(labelText: 'Usos máximos'),
                    items: const [
                      DropdownMenuItem<int>(value: 1, child: Text('1 uso')),
                      DropdownMenuItem<int>(value: 5, child: Text('5 usos')),
                      DropdownMenuItem<int>(value: 10, child: Text('10 usos')),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => maxUses = value);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () =>
                      Navigator.pop(ctx, (hours: hours, maxUses: maxUses)),
                  child: const Text('Gerar link'),
                ),
              ],
            ),
          );
        },
      );
      if (draft == null || !context.mounted) return;

      try {
        final created = await repo.createInvite(
          groupId,
          validFor: Duration(hours: draft.hours),
          maxUses: draft.maxUses,
        );
        onChanged();
        if (!context.mounted) return;
        final link = 'https://conexa.app/join/${created.token}';
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Copie o link agora'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.paper,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: SelectableText(
                    link,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const Text(
                  'Por segurança, guardamos apenas o hash. Este link não será '
                  'exibido novamente.',
                  style: TextStyle(color: AppColors.muted),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Fechar'),
              ),
              FilledButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: link));
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copiar link'),
              ),
            ],
          ),
        );
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nao foi possivel criar o convite.')),
          );
        }
      }
    }

    Future<void> revokeInvite(GroupInvite invite) async {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Revogar convite?'),
          content: const Text('O link deixa de funcionar imediatamente.'),
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
            const SnackBar(content: Text('Nao foi possivel revogar o convite.')),
          );
        }
      }
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        FilledButton.icon(
          onPressed: createInvite,
          icon: const Icon(Icons.add_link),
          label: const Text('Criar convite'),
        ),
        const SizedBox(height: AppSpacing.md),
        if (invites.isEmpty)
          Text(
            'Nenhum convite criado ainda.',
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
                        '${invite.usedCount} de ${invite.maxUses} usos',
                        style: theme.textTheme.titleSmall,
                      ),
                      Text(
                        'Validade: ${formatDate(invite.expiresAt)}',
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
                    style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                    child: const Text('Revogar'),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
