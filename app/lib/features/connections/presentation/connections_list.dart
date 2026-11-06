import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../chat/application/chat_providers.dart';
import '../../profile/application/profile_providers.dart';
import '../application/connection_providers.dart';
import '../data/connection_models.dart';

class ConnectionsList extends ConsumerWidget {
  const ConnectionsList({super.key});

  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nao foi possivel concluir a acao.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(connectionsProvider);
    final theme = Theme.of(context);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) =>
          const Center(child: Text('Erro ao carregar conexoes.')),
      data: (data) {
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(connectionsProvider);
            await ref.read(connectionsProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              if (data.incoming.isEmpty &&
                  data.outgoing.isEmpty &&
                  data.accepted.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.xl,
                  ),
                  child: Text(
                    'Nenhuma conexao ainda.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                ),
              if (data.incoming.isNotEmpty) ...[
                Text(
                  'Solicitacoes recebidas',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                ...data.incoming.map(
                  (c) => _incomingCard(context, ref, c),
                ),
              ],
              if (data.outgoing.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Text('Enviadas', style: theme.textTheme.titleSmall),
                ...data.outgoing.map(
                  (c) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: _ConnectionAvatar(path: c.avatarPath),
                    title: Text(c.displayName),
                    subtitle: const Text('Aguardando aprovacao'),
                  ),
                ),
              ],
              if (data.accepted.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Text('Conectados', style: theme.textTheme.titleSmall),
                ...data.accepted.map(
                  (c) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: _ConnectionAvatar(path: c.avatarPath),
                    title: Text(c.displayName),
                    trailing: TextButton(
                      onPressed: () => _run(context, () async {
                        final convId = await ref
                            .read(chatRepositoryProvider)
                            .startConversation(c.userId);
                        if (context.mounted) {
                          context.push('/chats/$convId');
                        }
                      }),
                      child: const Text('Mensagem'),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _incomingCard(
    BuildContext context,
    WidgetRef ref,
    ConnectionEntry c,
  ) {
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
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
              _ConnectionAvatar(path: c.avatarPath),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  c.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => _run(context, () async {
                    await ref
                        .read(connectionRepositoryProvider)
                        .respond(c.requesterId, true);
                    ref.invalidate(connectionsProvider);
                    ref.invalidate(conversationsProvider);
                  }),
                  child: const Text('Aceitar'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              OutlinedButton(
                onPressed: () => _run(context, () async {
                  await ref
                      .read(connectionRepositoryProvider)
                      .respond(c.requesterId, false);
                  ref.invalidate(connectionsProvider);
                }),
                child: const Text('Recusar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConnectionAvatar extends ConsumerWidget {
  const _ConnectionAvatar({this.path});

  final String? path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const fallback = CircleAvatar(
      backgroundColor: AppColors.teal,
      child: Icon(Icons.person, color: Colors.white),
    );
    if (path == null || path!.isEmpty) return fallback;
    final url = ref.watch(signedUrlProvider(path!));
    final value = url.asData?.value;
    if (value == null) return fallback;
    return CircleAvatar(backgroundImage: NetworkImage(value));
  }
}
