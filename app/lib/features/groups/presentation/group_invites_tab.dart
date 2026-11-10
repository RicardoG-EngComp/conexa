import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../chat/application/chat_providers.dart';
import '../../connections/application/connection_providers.dart';
import '../../connections/data/connection_models.dart';
import '../application/group_providers.dart';
import '../data/group_models.dart';
import 'group_common.dart';

enum _InviteShareAction { copy, post, message }

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
        final action = await _showLinkDialog(context, link);
        if (action == null || !context.mounted) return;

        switch (action) {
          case _InviteShareAction.copy:
            await Clipboard.setData(ClipboardData(text: link));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Link copiado.')),
              );
            }
          case _InviteShareAction.post:
            await _shareOnFeed(context, link);
          case _InviteShareAction.message:
            await _shareByMessage(context, ref, link);
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Não foi possível criar o convite.')),
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

  Future<_InviteShareAction?> _showLinkDialog(
    BuildContext context,
    String link,
  ) {
    return showDialog<_InviteShareAction>(
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
              'exibido novamente. Copie, publique no feed ou envie por '
              'mensagem agora.',
              style: TextStyle(color: AppColors.muted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _InviteShareAction.message),
            child: const Text('Enviar por mensagem'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _InviteShareAction.post),
            child: const Text('Publicar no feed'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, _InviteShareAction.copy),
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copiar link'),
          ),
        ],
      ),
    );
  }

  Future<void> _shareOnFeed(BuildContext context, String link) async {
    if (detail.visibility != 'public') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Publicar convite de grupo privado?'),
          content: Text(
            'Este grupo é privado. Qualquer pessoa que vir o post poderá entrar '
            'pelo link, até o limite de usos do convite. Deseja continuar?',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Publicar mesmo assim'),
            ),
          ],
        ),
      );
      if (ok != true || !context.mounted) return;
    }
    final text = 'Participe do grupo ${detail.name}: $link';
    context.push('/feed/compose?text=${Uri.encodeComponent(text)}');
  }

  Future<void> _shareByMessage(
    BuildContext context,
    WidgetRef ref,
    String link,
  ) async {
    final recipient = await showModalBottomSheet<ConnectionEntry>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.paper,
      builder: (_) => _ConnectionsPicker(),
    );
    if (recipient == null || !context.mounted) return;

    try {
      final chat = ref.read(chatRepositoryProvider);
      final conversationId = await chat.startConversation(recipient.userId);
      await chat.sendMessage(
        conversationId: conversationId,
        content: 'Convite para o grupo ${detail.name}: $link',
        flagged: false,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Convite enviado para ${recipient.displayName}.'),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível enviar a mensagem.')),
        );
      }
    }
  }
}

class _ConnectionsPicker extends ConsumerWidget {
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
                'Enviar para uma conexão',
                style: theme.textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(
                'Você só pode enviar convites por mensagem para conexões aceitas.',
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
