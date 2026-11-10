import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/group_providers.dart';
import '../data/group_models.dart';
import 'group_common.dart';

class GroupInvitesReceivedScreen extends ConsumerWidget {
  const GroupInvitesReceivedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final invitesAsync = ref.watch(myGroupInvitesProvider);
    final repo = ref.read(groupRepositoryProvider);

    Future<void> accept(GroupInvitation invite) async {
      try {
        final groupId = await repo.acceptInvite(invite.inviteId);
        ref.invalidate(myGroupInvitesProvider);
        ref.invalidate(myGroupsProvider);
        if (context.mounted) {
          context.go('/groups');
          context.push('/groups/$groupId');
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_error(e.toString()))),
          );
        }
      }
    }

    Future<void> decline(GroupInvitation invite) async {
      try {
        await repo.declineInvite(invite.inviteId);
        ref.invalidate(myGroupInvitesProvider);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Não foi possível recusar.')),
          );
        }
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Convites recebidos')),
      body: SafeArea(
        child: invitesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) =>
              const Center(child: Text('Erro ao carregar convites.')),
          data: (invites) {
            if (invites.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 48,
                        color: AppColors.muted.withValues(alpha: 0.6),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Nenhum convite pendente.',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Quando alguém convidar você para um grupo, o convite '
                        'aparece aqui e no sino de notificações.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                for (final invite in invites)
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
                            GroupAvatar(name: invite.groupName, radius: 20),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          invite.groupName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.titleSmall,
                                        ),
                                      ),
                                      if (invite.groupOfficial) ...[
                                        const SizedBox(width: 4),
                                        const Icon(
                                          Icons.verified,
                                          size: 15,
                                          color: AppColors.teal,
                                        ),
                                      ],
                                    ],
                                  ),
                                  Text(
                                    '${invite.groupCategory} · convite de '
                                    '${invite.inviterName}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Válido até ${formatDate(invite.expiresAt)}.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => decline(invite),
                                child: const Text('Recusar'),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: FilledButton(
                                onPressed: () => accept(invite),
                                child: const Text('Entrar no grupo'),
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
      ),
    );
  }

  String _error(String raw) {
    if (raw.contains('convite expirado')) return 'Este convite expirou.';
    if (raw.contains('convite revogado')) return 'Este convite foi revogado.';
    if (raw.contains('convite esgotado')) {
      return 'Este convite atingiu o limite de usos.';
    }
    if (raw.contains('convite invalido')) return 'Convite inválido.';
    if (raw.contains('nao_verificado')) {
      return 'Sua conta precisa estar verificada.';
    }
    if (raw.contains('diretrizes_necessarias')) {
      return 'Aceite as Diretrizes da Comunidade para continuar.';
    }
    return 'Não foi possível entrar no grupo.';
  }
}
