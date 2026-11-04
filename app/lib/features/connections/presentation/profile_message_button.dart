import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../chat/application/chat_providers.dart';
import '../application/connection_providers.dart';

class ProfileMessageButton extends ConsumerWidget {
  const ProfileMessageButton({
    super.key,
    required this.targetId,
    required this.onRequestMessage,
  });

  final String targetId;
  final VoidCallback onRequestMessage;

  Future<void> _openChat(BuildContext context, WidgetRef ref) async {
    try {
      final convId = await ref
          .read(chatRepositoryProvider)
          .startConversation(targetId);
      if (context.mounted) context.push('/chats/$convId');
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nao foi possivel abrir a conversa.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(connectionStatusProvider(targetId));

    return statusAsync.maybeWhen(
      data: (status) => status.status == 'accepted'
          ? FilledButton.icon(
              onPressed: () => _openChat(context, ref),
              icon: const Icon(Icons.chat_bubble_outline, size: 18),
              label: const Text('Mensagem'),
            )
          : FilledButton.icon(
              onPressed: onRequestMessage,
              icon: const Icon(Icons.mail_outline, size: 18),
              label: const Text('Pedido de mensagem'),
            ),
      orElse: () => FilledButton.icon(
        onPressed: onRequestMessage,
        icon: const Icon(Icons.mail_outline, size: 18),
        label: const Text('Pedido de mensagem'),
      ),
    );
  }
}
