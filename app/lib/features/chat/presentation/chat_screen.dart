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
  final _scrollController = ScrollController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(chatRepositoryProvider).markAsRead(widget.id);
      ref.invalidate(conversationsProvider);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
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
                  _scrollToBottom();
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
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
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: mine ? Colors.white : AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Align(
                    alignment: Alignment.centerRight,
                    widthFactor: 1,
                    child: Text(
                      _formatTime(message.createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 10,
                        color: mine ? Colors.white70 : AppColors.muted,
                      ),
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

String _formatTime(DateTime date) {
  final local = date.toLocal();
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}
