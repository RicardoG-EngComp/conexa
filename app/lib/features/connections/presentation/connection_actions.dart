import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../chat/application/chat_providers.dart';
import '../application/connection_providers.dart';

class ConnectionActions extends ConsumerWidget {
  const ConnectionActions({super.key, required this.targetId});

  final String targetId;

  Future<void> _send(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(connectionRepositoryProvider).sendRequest(targetId);
      ref.invalidate(connectionStatusProvider(targetId));
      ref.invalidate(connectionsProvider);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Nao foi possivel conectar. Complete seu perfil e tente novamente.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(connectionStatusProvider(targetId));

    return statusAsync.when(
      loading: () => const SizedBox(
        height: 36,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (status) {
        switch (status.status) {
          case 'accepted':
            return const Chip(
              avatar: Icon(Icons.people, size: 16),
              label: Text('Conectado'),
            );
          case 'pending_out':
            return const OutlinedButton(
              onPressed: null,
              child: Text('Solicitacao enviada'),
            );
          case 'pending_in':
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () async {
                    await ref
                        .read(connectionRepositoryProvider)
                        .respond(status.requesterId!, false);
                    ref.invalidate(connectionStatusProvider(targetId));
                    ref.invalidate(connectionsProvider);
                  },
                  child: const Text('Recusar'),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton(
                  onPressed: () async {
                    await ref
                        .read(connectionRepositoryProvider)
                        .respond(status.requesterId!, true);
                    ref.invalidate(connectionStatusProvider(targetId));
                    ref.invalidate(connectionsProvider);
                    ref.invalidate(conversationsProvider);
                  },
                  child: const Text('Aceitar conexao'),
                ),
              ],
            );
          case 'declined':
            return const Text('Conexao recusada.');
          default:
            return OutlinedButton.icon(
              onPressed: () => _send(context, ref),
              icon: const Icon(Icons.person_add_alt_1, size: 18),
              label: const Text('Conectar'),
            );
        }
      },
    );
  }
}
