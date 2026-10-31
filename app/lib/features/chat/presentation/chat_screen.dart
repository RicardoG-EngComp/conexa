import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../reports/presentation/report_dialog.dart';
import '../application/chat_providers.dart';
import '../data/chat_models.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.id, this.summary});

  final String id;
  final ConversationSummary? summary;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final result = ref.read(moderationServiceProvider).check(text);
    if (result.flagged) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Atencao'),
          content: Text(
            result.reason ??
                'Esta mensagem pode ser interpretada como assedio. '
                    'Deseja enviar mesmo assim?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Enviar mesmo assim'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    setState(() => _sending = true);
    try {
      await ref
          .read(chatRepositoryProvider)
          .sendMessage(
            conversationId: widget.id,
            content: text,
            flagged: result.flagged,
          );
      _controller.clear();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nao foi possivel enviar.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final myId = Supabase.instance.client.auth.currentUser?.id;
    final messagesAsync = ref.watch(messagesStreamProvider(widget.id));

    return Scaffold(
      appBar: AppBar(title: Text(widget.summary?.otherName ?? 'Conversa')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: messagesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) =>
                    const Center(child: Text('Erro ao carregar mensagens.')),
                data: (messages) {
                  if (messages.isEmpty) {
                    return Center(
                      child: Text(
                        'Diga oi!',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                    );
                  }
                  final reversed = messages.reversed.toList();
                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: reversed.length,
                    itemBuilder: (context, index) {
                      final message = reversed[index];
                      final mine = message.senderId == myId;
                      return _Bubble(
                        message: message,
                        mine: mine,
                        onReport: mine
                            ? null
                            : () => showReportDialog(
                                context,
                                ref,
                                reportedUserId: message.senderId,
                                targetType: 'message',
                                targetId: message.id,
                                contentSnapshot: message.content,
                              ),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Mensagem...',
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.mine, this.onReport});

  final ChatMessage message;
  final bool mine;
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!mine)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_horiz, size: 18),
              onSelected: (_) => onReport?.call(),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'report', child: Text('Denunciar')),
              ],
            ),
          Flexible(
            child: Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              constraints: const BoxConstraints(maxWidth: 280),
              decoration: BoxDecoration(
                color: mine ? AppColors.teal : AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: mine ? Colors.white : AppColors.ink,
                    ),
                  ),
                  if (message.flagged) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 12,
                          color: mine ? Colors.white70 : AppColors.muted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'sinalizada',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: mine ? Colors.white70 : AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
