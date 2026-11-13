import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/media/media_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/connection_providers.dart';
import '../data/connection_models.dart';

class SentConnectionsScreen extends ConsumerWidget {
  const SentConnectionsScreen({super.key});

  Future<void> _cancel(
    BuildContext context,
    WidgetRef ref,
    ConnectionEntry entry,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar solicitacao?'),
        content: Text(
          'A solicitacao para ${entry.displayName} sera cancelada.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancelar solicitacao'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;

    try {
      await ref.read(connectionRepositoryProvider).cancelRequest(entry.userId);
      ref.invalidate(connectionsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Solicitacao cancelada.')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nao foi possivel cancelar a solicitacao.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(connectionsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Solicitacoes enviadas')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            const Center(child: Text('Erro ao carregar solicitacoes.')),
        data: (data) {
          final outgoing = data.outgoing;
          if (outgoing.isEmpty) {
            return Center(
              child: Text(
                'Nenhuma solicitacao enviada.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppColors.muted,
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(connectionsProvider);
              await ref.read(connectionsProvider.future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: outgoing.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (context, index) {
                final entry = outgoing[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: _SentAvatar(path: entry.avatarPath),
                  title: Text(entry.displayName),
                  subtitle: const Text('Aguardando aprovacao'),
                  onTap: () => context.push('/profile/${entry.userId}'),
                  trailing: TextButton(
                    onPressed: () => _cancel(context, ref, entry),
                    child: const Text('Cancelar'),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _SentAvatar extends ConsumerWidget {
  const _SentAvatar({this.path});

  final String? path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const fallback = CircleAvatar(
      backgroundColor: AppColors.teal,
      child: Icon(Icons.person, color: Colors.white),
    );
    if (path == null || path!.isEmpty) return fallback;
    return ClipOval(
      child: SizedBox(
        width: 40,
        height: 40,
        child: MediaImage(path: path!, width: 40, height: 40),
      ),
    );
  }
}
