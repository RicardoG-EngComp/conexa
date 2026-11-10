import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/moderation_errors.dart';
import '../../../core/errors/moderation_ui.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../reports/presentation/report_dialog.dart';
import '../../stickers/presentation/sticker_picker_sheet.dart';
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
    } catch (error) {
      if (mounted) {
        if (needsGuidelinesAcceptance(error)) {
          await showGuidelinesConsentDialog(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                friendlyModerationError(
                  error,
                  fallback: 'Nao foi possivel enviar.',
                ),
              ),
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _openStickerPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => StickerPickerSheet(conversationId: widget.id),
    );
  }

  bool _canDeleteForEveryone(ChatMessage message) {
    final mine =
        message.senderId == Supabase.instance.client.auth.currentUser?.id;
    if (!mine || message.deletedForEveryone) return false;
    return DateTime.now().toUtc().difference(message.createdAt.toUtc()) <
        const Duration(minutes: 5);
  }

  Future<void> _showMessageActions(ChatMessage message) async {
    final mine =
        message.senderId == Supabase.instance.client.auth.currentUser?.id;
    final canDeleteForEveryone = _canDeleteForEveryone(message);

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Apagar para mim'),
              onTap: () {
                Navigator.pop(sheetContext);
                _deleteForMe(message);
              },
            ),
            if (canDeleteForEveryone)
              ListTile(
                leading: const Icon(
                  Icons.delete_forever_outlined,
                  color: AppColors.danger,
                ),
                title: const Text(
                  'Apagar para todos',
                  style: TextStyle(color: AppColors.danger),
                ),
                subtitle: const Text('Disponivel por 5 minutos apos o envio.'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _deleteForEveryone(message);
                },
              ),
            if (!mine)
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Denunciar'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  showReportDialog(
                    context,
                    ref,
                    reportedUserId: message.senderId,
                    targetType: 'message',
                    targetId: message.id,
                    contentSnapshot: message.kind == 'text'
                        ? message.content
                        : message.kind == 'sticker'
                        ? '[figurinha]'
                        : '[GIF]',
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteForMe(ChatMessage message) async {
    try {
      await ref.read(chatRepositoryProvider).deleteMessageForMe(message.id);
      ref.invalidate(messagesStreamProvider(widget.id));
      ref.invalidate(conversationsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mensagem apagada para voce.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nao foi possivel apagar a mensagem.')),
        );
      }
    }
  }

  Future<void> _deleteForEveryone(ChatMessage message) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apagar para todos?'),
        content: const Text(
          'A mensagem sera apagada para voce e para a outra pessoa. '
          'Esta acao nao pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Apagar para todos'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await ref
          .read(chatRepositoryProvider)
          .deleteMessageForEveryone(message.id);
      ref.invalidate(conversationsProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Nao foi possivel apagar para todos. O prazo de 5 minutos '
              'pode ter expirado.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _clearConversation() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Limpar conversa?'),
        content: const Text(
          'As mensagens somem apenas para voce. A outra pessoa continua '
          'vendo o historico.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Limpar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await ref.read(chatRepositoryProvider).clearConversation(widget.id);
      ref.invalidate(messagesStreamProvider(widget.id));
      ref.invalidate(conversationsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conversa limpa para voce.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nao foi possivel limpar a conversa.')),
        );
      }
    }
  }

  Future<void> _deleteConversation() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir conversa?'),
        content: const Text(
          'A conversa some da sua lista. Se a outra pessoa enviar uma nova '
          'mensagem, ela volta a aparecer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await ref.read(chatRepositoryProvider).deleteConversation(widget.id);
      ref.invalidate(conversationsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nao foi possivel excluir a conversa.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final myId = Supabase.instance.client.auth.currentUser?.id;
    final messagesAsync = ref.watch(messagesStreamProvider(widget.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.summary?.otherName ?? 'Conversa'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'clear') {
                _clearConversation();
              } else if (value == 'delete') {
                _deleteConversation();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'clear', child: Text('Limpar conversa')),
              PopupMenuItem(value: 'delete', child: Text('Excluir conversa')),
            ],
          ),
        ],
      ),
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
                        onLongPress: () => _showMessageActions(message),
                        onReport: mine
                            ? null
                            : () => showReportDialog(
                                context,
                                ref,
                                reportedUserId: message.senderId,
                                targetType: 'message',
                                targetId: message.id,
                                contentSnapshot: message.kind == 'text'
                                    ? message.content
                                    : message.kind == 'sticker'
                                    ? '[figurinha]'
                                    : '[GIF]',
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
                  IconButton(
                    onPressed: _sending ? null : _openStickerPicker,
                    icon: const Icon(Icons.emoji_emotions_outlined),
                  ),
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
  const _Bubble({
    required this.message,
    required this.mine,
    this.onReport,
    this.onLongPress,
  });

  final ChatMessage message;
  final bool mine;
  final VoidCallback? onReport;
  final VoidCallback? onLongPress;

  Widget _content(ThemeData theme) {
    if (message.deletedForEveryone) {
      return Text(
        'Mensagem apagada',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: AppColors.muted,
          fontStyle: FontStyle.italic,
        ),
      );
    }
    if (message.kind == 'sticker' && message.stickerPath != null) {
      return Image.network(
        Supabase.instance.client.storage
            .from('stickers')
            .getPublicUrl(message.stickerPath!),
        width: 140,
        height: 140,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) =>
            const Icon(Icons.broken_image_outlined, color: AppColors.muted),
      );
    }
    if (message.kind == 'gif' && message.gifUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Image.network(
          message.gifUrl!,
          width: 200,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) =>
              const Icon(Icons.broken_image_outlined, color: AppColors.muted),
        ),
      );
    }
    return Text(
      message.content,
      style: theme.textTheme.bodyLarge?.copyWith(
        color: mine ? Colors.white : AppColors.ink,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final deleted = message.deletedForEveryone;
    final media = !deleted && message.kind != 'text';
    final bubbleColor = deleted
        ? AppColors.surface
        : mine
        ? AppColors.teal
        : AppColors.surface;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!mine && !deleted)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_horiz, size: 18),
              onSelected: (_) => onReport?.call(),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'report', child: Text('Denunciar')),
              ],
            ),
          Flexible(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onLongPress: onLongPress,
              child: Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                padding: media
                    ? EdgeInsets.zero
                    : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                constraints: const BoxConstraints(maxWidth: 280),
                decoration: media
                    ? null
                    : BoxDecoration(
                        color: bubbleColor,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.border),
                      ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _content(theme),
                    const SizedBox(height: 2),
                    Align(
                      alignment: Alignment.centerRight,
                      widthFactor: 1,
                      child: Text(
                        _formatTime(message.createdAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                          color: deleted || media || !mine
                              ? AppColors.muted
                              : Colors.white70,
                        ),
                      ),
                    ),
                    if (message.flagged && !deleted) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 12,
                            color: media || !mine
                                ? AppColors.muted
                                : Colors.white70,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'sinalizada',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: media || !mine
                                  ? AppColors.muted
                                  : Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
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
