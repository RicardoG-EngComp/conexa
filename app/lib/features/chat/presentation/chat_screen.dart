import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/moderation_errors.dart';
import '../../../core/errors/moderation_ui.dart';
import '../../../core/media/image_processor.dart';
import '../../../core/media/media_models.dart';
import '../../../core/media/media_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/uuid.dart';
import '../../connections/application/connection_providers.dart';
import '../../reports/presentation/report_dialog.dart';
import '../../stickers/presentation/sticker_picker_sheet.dart';
import '../application/chat_providers.dart';
import '../data/chat_models.dart';
import 'chat_media_view.dart';

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
  final _focusNode = FocusNode();
  final _picker = ImagePicker();

  bool _sending = false;
  bool _uploading = false;
  ChatMessage? _replyTo;
  ChatMessage? _editing;
  ChatMediaDraft? _media;
  Timer? _typingTimer;
  bool _typingSent = false;

  String? get _myId => Supabase.instance.client.auth.currentUser?.id;

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
    if (_typingSent) {
      unawaited(ref.read(chatRepositoryProvider).setTyping(widget.id, false));
    }
    _typingTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
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

  void _onTextChanged(String value) {
    final typing = value.trim().isNotEmpty;
    if (!typing) {
      unawaited(_stopTyping());
      return;
    }
    if (!_typingSent) {
      _typingSent = true;
      unawaited(ref.read(chatRepositoryProvider).setTyping(widget.id, true));
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 4), () {
      if (!_typingSent) return;
      _typingSent = false;
      unawaited(ref.read(chatRepositoryProvider).setTyping(widget.id, false));
    });
  }

  Future<void> _stopTyping() async {
    _typingTimer?.cancel();
    if (!_typingSent) return;
    _typingSent = false;
    try {
      await ref.read(chatRepositoryProvider).setTyping(widget.id, false);
    } catch (_) {}
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    final editing = _editing;
    var flagged = false;

    if (editing != null) {
      if (text.isEmpty) return;
      setState(() => _sending = true);
      try {
        await ref.read(chatRepositoryProvider).editMessage(editing.id, text);
        _controller.clear();
        setState(() => _editing = null);
        await _stopTyping();
      } catch (_) {
        _snack('Nao foi possivel editar. O prazo pode ter expirado.');
      } finally {
        if (mounted) setState(() => _sending = false);
      }
      return;
    }

    if (text.isEmpty && _media == null) return;

    if (text.isNotEmpty) {
      final result = ref.read(moderationServiceProvider).check(text);
      if (result.flagged) {
        flagged = true;
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
    }

    setState(() => _sending = true);
    try {
      final media = _media;
      await ref
          .read(chatRepositoryProvider)
          .sendMessage(
            conversationId: widget.id,
            content: text,
            flagged: flagged,
            kind: media?.kind ?? 'text',
            replyToId: _replyTo?.id,
            mediaPath: media?.path,
            mediaMime: media?.mimeType,
            mediaBytes: media?.byteSize,
            mediaWidth: media?.width,
            mediaHeight: media?.height,
            mediaDurationMs: media?.durationMs,
            mediaName: media?.name,
          );
      _controller.clear();
      setState(() {
        _media = null;
        _replyTo = null;
      });
      await _stopTyping();
      ref.invalidate(conversationsProvider);
    } catch (error) {
      if (mounted) {
        if (needsGuidelinesAcceptance(error)) {
          await showGuidelinesConsentDialog(context);
        } else {
          _snack(
            friendlyModerationError(
              error,
              fallback: 'Nao foi possivel enviar.',
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickMedia() async {
    final kind = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('Imagem'),
              onTap: () => Navigator.pop(ctx, 'image'),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('PDF'),
              subtitle: const Text('Ate 10 MB.'),
              onTap: () => Navigator.pop(ctx, 'file'),
            ),
          ],
        ),
      ),
    );
    if (kind == null) return;

    setState(() => _uploading = true);
    try {
      if (kind == 'image') {
        final picked = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 90,
        );
        if (picked == null) return;
        final processed = await ImageProcessor.feedImage(
          await picked.readAsBytes(),
        );
        final assetId = uuidV4();
        final media = ref.read(mediaServiceProvider);
        final uploaded = await media.uploadImage(
          bytes: processed.full,
          kind: 'chat_image',
          variant: 'full',
          contentType: 'image/webp',
          assetId: assetId,
          width: processed.width,
          height: processed.height,
        );
        try {
          await media.uploadImage(
            bytes: processed.thumb,
            kind: 'chat_image',
            variant: 'thumb',
            contentType: 'image/webp',
            assetId: assetId,
            width: processed.thumbWidth,
            height: processed.thumbHeight,
          );
        } catch (_) {}
        setState(() {
          _media = ChatMediaDraft(
            path: uploaded.key,
            kind: 'image',
            mimeType: 'image/webp',
            byteSize: uploaded.bytes,
            width: processed.width,
            height: processed.height,
            name: picked.name,
          );
        });
      } else {
        final files = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf'],
        );
        if (files.isEmpty) return;
        final file = files.first;
        final bytes = await file.xFile.readAsBytes();
        if (bytes.length > 10 * 1024 * 1024) {
          _snack('Arquivo muito grande. Limite de 10 MB.');
          return;
        }
        final uploaded = await ref
            .read(mediaServiceProvider)
            .uploadBytes(
              bytes: bytes,
              kind: 'chat_file',
              variant: 'full',
              contentType: 'application/pdf',
            );
        setState(() {
          _media = ChatMediaDraft(
            path: uploaded.key,
            kind: 'file',
            mimeType: 'application/pdf',
            byteSize: uploaded.bytes,
            name: file.name,
          );
        });
      }
    } on MediaException catch (error) {
      _snack(_mediaError(error.code));
    } catch (_) {
      _snack('Nao foi possivel enviar a midia.');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  String _mediaError(String code) {
    return switch (code) {
      'quota_chat_imagens' => 'Limite diario de imagens atingido.',
      'quota_chat_videos' => 'Limite diario de videos atingido.',
      'quota_chat_arquivos' => 'Limite diario de arquivos atingido.',
      'quota_chat_bytes' => 'Limite mensal de midia atingido.',
      'arquivo_muito_grande' => 'Arquivo muito grande.',
      'tipo_ou_variante_invalida' => 'Formato nao suportado.',
      _ => 'Nao foi possivel enviar a midia.',
    };
  }

  Future<void> _openStickerPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => StickerPickerSheet(conversationId: widget.id),
    );
    ref.invalidate(conversationsProvider);
  }

  bool _canDeleteForEveryone(ChatMessage message) {
    final mine = message.senderId == _myId;
    if (!mine || message.deletedForEveryone) return false;
    return DateTime.now().toUtc().difference(message.createdAt.toUtc()) <
        const Duration(minutes: 5);
  }

  bool _canEdit(ChatMessage message) {
    if (message.senderId != _myId ||
        message.kind != 'text' ||
        message.deletedForEveryone) {
      return false;
    }
    return DateTime.now().toUtc().difference(message.createdAt.toUtc()) <
        const Duration(minutes: 15);
  }

  void _startReply(ChatMessage message) {
    setState(() {
      _editing = null;
      _replyTo = message;
    });
    _focusNode.requestFocus();
  }

  void _startEdit(ChatMessage message) {
    setState(() {
      _replyTo = null;
      _editing = message;
      _controller.text = message.content;
    });
    _focusNode.requestFocus();
  }

  Future<void> _showReactionPicker(ChatMessage message) async {
    const emojis = ['❤️', '😂', '😮', '😢', '👍', '👏'];
    final emoji = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (final item in emojis)
                InkWell(
                  onTap: () => Navigator.pop(ctx, item),
                  borderRadius: BorderRadius.circular(999),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(item, style: const TextStyle(fontSize: 28)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (emoji == null) return;
    try {
      await ref.read(chatRepositoryProvider).toggleReaction(message.id, emoji);
    } catch (_) {
      _snack('Nao foi possivel reagir.');
    }
  }

  Future<void> _showMessageActions(ChatMessage message) async {
    final mine = message.senderId == _myId;
    final canDeleteForEveryone = _canDeleteForEveryone(message);
    final canEdit = _canEdit(message);

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!message.deletedForEveryone)
              ListTile(
                leading: const Icon(Icons.emoji_emotions_outlined),
                title: const Text('Reagir'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showReactionPicker(message);
                },
              ),
            if (!message.deletedForEveryone)
              ListTile(
                leading: const Icon(Icons.reply),
                title: const Text('Responder'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _startReply(message);
                },
              ),
            if (canEdit)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Editar'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _startEdit(message);
                },
              ),
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
                    contentSnapshot: _reportPreview(message),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  String _reportPreview(ChatMessage message) {
    return switch (message.kind) {
      'text' => message.content,
      'sticker' => '[figurinha]',
      'gif' => '[GIF]',
      'image' => '[imagem]',
      'video' => '[video]',
      'file' => '[arquivo]',
      _ => '[mensagem]',
    };
  }

  Future<void> _deleteForMe(ChatMessage message) async {
    try {
      await ref.read(chatRepositoryProvider).deleteMessageForMe(message.id);
      ref.invalidate(messagesStreamProvider(widget.id));
      ref.invalidate(conversationsProvider);
      _snack('Mensagem apagada para voce.');
    } catch (_) {
      _snack('Nao foi possivel apagar a mensagem.');
    }
  }

  Future<void> _deleteForEveryone(ChatMessage message) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apagar para todos?'),
        content: const Text(
          'A mensagem sera apagada para voce e para os outros participantes. '
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
      _snack('Nao foi possivel apagar para todos. O prazo pode ter expirado.');
    }
  }

  Future<void> _clearConversation() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Limpar conversa?'),
        content: const Text(
          'As mensagens somem apenas para voce. Os outros participantes '
          'continuam vendo o historico.',
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
      _snack('Conversa limpa para voce.');
    } catch (_) {
      _snack('Nao foi possivel limpar a conversa.');
    }
  }

  Future<void> _deleteConversation() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir conversa?'),
        content: const Text(
          'A conversa some da sua lista. Se alguem enviar uma nova mensagem, '
          'ela volta a aparecer.',
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
      _snack('Nao foi possivel excluir a conversa.');
    }
  }

  Future<void> _togglePin(ConversationSummary? summary) async {
    try {
      await ref
          .read(chatRepositoryProvider)
          .setPinned(widget.id, !(summary?.pinned ?? false));
      ref.invalidate(conversationsProvider);
    } catch (_) {
      _snack('Nao foi possivel fixar.');
    }
  }

  Future<void> _toggleMute(ConversationSummary? summary) async {
    try {
      await ref
          .read(chatRepositoryProvider)
          .setMuted(widget.id, !(summary?.muted ?? false));
      ref.invalidate(conversationsProvider);
    } catch (_) {
      _snack('Nao foi possivel silenciar.');
    }
  }

  Future<void> _toggleArchive(ConversationSummary? summary) async {
    final archiving = !(summary?.archived ?? false);
    try {
      await ref.read(chatRepositoryProvider).setArchived(widget.id, archiving);
      ref.invalidate(conversationsProvider);
      if (archiving && mounted) Navigator.of(context).pop();
    } catch (_) {
      _snack('Nao foi possivel arquivar.');
    }
  }

  void _showMembers() {
    showDialog<void>(
      context: context,
      builder: (_) => _MembersDialog(conversationId: widget.id),
    );
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  ConversationSummary? _summaryFromList(WidgetRef ref) {
    final data = ref.watch(conversationsProvider).asData?.value;
    if (data == null) return widget.summary;
    for (final item in data) {
      if (item.id == widget.id) return item;
    }
    return widget.summary;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final myId = _myId;
    final messagesAsync = ref.watch(messagesStreamProvider(widget.id));
    final reactionsAsync = ref.watch(reactionsStreamProvider(widget.id));
    final typingAsync = ref.watch(typingStreamProvider(widget.id));
    final membersAsync = ref.watch(chatMembersProvider(widget.id));
    final summary = _summaryFromList(ref);

    final reactionsByMessage = <String, List<MessageReaction>>{};
    for (final reaction in reactionsAsync.asData?.value ?? const []) {
      reactionsByMessage
          .putIfAbsent(reaction.messageId, () => [])
          .add(reaction);
    }

    final memberNames = <String, String>{
      for (final member in membersAsync.asData?.value ?? const [])
        member.userId: member.displayName,
    };

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              summary?.displayName ?? widget.summary?.displayName ?? 'Conversa',
            ),
            if (summary?.isGroup == true)
              Text(
                '${summary!.memberCount} participantes',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.muted,
                ),
              ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'members':
                  _showMembers();
                case 'pin':
                  _togglePin(summary);
                case 'mute':
                  _toggleMute(summary);
                case 'archive':
                  _toggleArchive(summary);
                case 'clear':
                  _clearConversation();
                case 'delete':
                  _deleteConversation();
              }
            },
            itemBuilder: (_) => [
              if (summary?.isGroup == true)
                const PopupMenuItem(
                  value: 'members',
                  child: Text('Participantes'),
                ),
              PopupMenuItem(
                value: 'pin',
                child: Text(
                  summary?.pinned == true
                      ? 'Desafixar conversa'
                      : 'Fixar conversa',
                ),
              ),
              PopupMenuItem(
                value: 'mute',
                child: Text(
                  summary?.muted == true
                      ? 'Reativar notificacoes'
                      : 'Silenciar',
                ),
              ),
              PopupMenuItem(
                value: 'archive',
                child: Text(
                  summary?.archived == true ? 'Desarquivar' : 'Arquivar',
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: Text('Limpar conversa'),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Excluir conversa'),
              ),
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
                  final byId = {for (final m in messages) m.id: m};
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final mine = message.senderId == myId;
                      final reply = message.replyToId == null
                          ? null
                          : byId[message.replyToId];
                      return _Bubble(
                        message: message,
                        mine: mine,
                        senderName: summary?.isGroup == true && !mine
                            ? memberNames[message.senderId]
                            : null,
                        reply: reply,
                        replyAuthor: reply == null
                            ? null
                            : memberNames[reply.senderId],
                        reactions: reactionsByMessage[message.id] ?? const [],
                        myId: myId,
                        onLongPress: () => _showMessageActions(message),
                        onReactionTap: (emoji) async {
                          try {
                            await ref
                                .read(chatRepositoryProvider)
                                .toggleReaction(message.id, emoji);
                          } catch (_) {}
                        },
                      );
                    },
                  );
                },
              ),
            ),
            _TypingIndicator(
              typing: typingAsync.asData?.value ?? const [],
              myId: myId,
              names: memberNames,
            ),
            if (_editing != null || _replyTo != null || _media != null)
              _ComposeContext(
                editing: _editing != null,
                replyName: _replyTo == null
                    ? null
                    : memberNames[_replyTo!.senderId] ??
                          (mine(_replyTo!) ? 'Voce' : 'Mensagem'),
                media: _media,
                onCancel: () {
                  setState(() {
                    _replyTo = null;
                    _editing = null;
                    _media = null;
                  });
                  _controller.clear();
                },
              ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _uploading || _sending ? null : _pickMedia,
                    icon: _uploading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.attach_file),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      minLines: 1,
                      maxLines: 4,
                      onChanged: _onTextChanged,
                      decoration: InputDecoration(
                        hintText: _media == null
                            ? 'Mensagem...'
                            : 'Legenda (opcional)',
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  IconButton(
                    onPressed: _sending ? null : _openStickerPicker,
                    icon: const Icon(Icons.emoji_emotions_outlined),
                  ),
                  IconButton.filled(
                    onPressed: _sending || _uploading ? null : _send,
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

  bool mine(ChatMessage message) => message.senderId == _myId;
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator({
    required this.typing,
    required this.myId,
    required this.names,
  });

  final List<Map<String, dynamic>> typing;
  final String? myId;
  final Map<String, String> names;

  @override
  Widget build(BuildContext context) {
    final cutoff = DateTime.now().toUtc().subtract(const Duration(seconds: 10));
    final active = typing.where((row) {
      if (row['user_id'] == myId) return false;
      final updated = DateTime.parse(row['updated_at'] as String).toUtc();
      return updated.isAfter(cutoff);
    }).toList();
    if (active.isEmpty) return const SizedBox.shrink();
    final labels = active
        .map((row) => names[row['user_id']] ?? 'Alguem')
        .toSet()
        .toList();
    final text = labels.length == 1
        ? '${labels.first} esta digitando...'
        : '${labels.take(2).join(', ')} estao digitando...';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: AppColors.muted),
        ),
      ),
    );
  }
}

class _ComposeContext extends StatelessWidget {
  const _ComposeContext({
    required this.editing,
    required this.replyName,
    required this.media,
    required this.onCancel,
  });

  final bool editing;
  final String? replyName;
  final ChatMediaDraft? media;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = editing
        ? 'Editando mensagem'
        : replyName != null
        ? 'Respondendo a $replyName'
        : media?.kind == 'image'
        ? 'Imagem anexada'
        : media?.kind == 'video'
        ? 'Video anexado'
        : 'Arquivo anexado';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      color: AppColors.paper,
      child: Row(
        children: [
          Icon(
            editing
                ? Icons.edit_outlined
                : replyName != null
                ? Icons.reply
                : Icons.attach_file,
            size: 16,
            color: AppColors.teal,
          ),
          const SizedBox(width: 6),
          Expanded(child: Text(label, style: theme.textTheme.labelMedium)),
          InkWell(onTap: onCancel, child: const Icon(Icons.close, size: 18)),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.mine,
    required this.reply,
    required this.replyAuthor,
    required this.reactions,
    required this.myId,
    this.senderName,
    this.onLongPress,
    this.onReactionTap,
  });

  final ChatMessage message;
  final bool mine;
  final String? senderName;
  final ChatMessage? reply;
  final String? replyAuthor;
  final List<MessageReaction> reactions;
  final String? myId;
  final VoidCallback? onLongPress;
  final void Function(String emoji)? onReactionTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final deleted = message.deletedForEveryone;
    final bubbleColor = deleted
        ? AppColors.surface
        : mine
        ? AppColors.teal
        : AppColors.surface;
    final grouped = <String, List<MessageReaction>>{};
    for (final reaction in reactions) {
      grouped.putIfAbsent(reaction.emoji, () => []).add(reaction);
    }

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: onLongPress,
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          constraints: const BoxConstraints(maxWidth: 300),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (senderName != null && senderName!.isNotEmpty) ...[
                Text(
                  senderName!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.teal,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
              ],
              if (reply != null) ...[
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: mine
                        ? Colors.white.withValues(alpha: 0.12)
                        : AppColors.paper,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    '${replyAuthor ?? 'Mensagem'}: '
                    '${reply!.content.isEmpty ? _kindLabel(reply!.kind) : reply!.content}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: mine ? Colors.white70 : AppColors.muted,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
              ],
              if (deleted)
                Text(
                  'Mensagem apagada',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.muted,
                    fontStyle: FontStyle.italic,
                  ),
                )
              else if (message.hasMedia)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ChatMediaView(message: message),
                    if (message.content.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        message.content,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: mine ? Colors.white : AppColors.ink,
                        ),
                      ),
                    ],
                  ],
                )
              else
                _textContent(theme),
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message.editedAt != null && !deleted) ...[
                    Text(
                      'editada',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 10,
                        color: mine ? Colors.white70 : AppColors.muted,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    _formatTime(message.createdAt),
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 10,
                      color: mine ? Colors.white70 : AppColors.muted,
                    ),
                  ),
                  if (message.flagged && !deleted) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 12,
                      color: mine ? Colors.white70 : AppColors.muted,
                    ),
                  ],
                ],
              ),
              if (grouped.isNotEmpty) ...[
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  children: [
                    for (final entry in grouped.entries)
                      InkWell(
                        onTap: onReactionTap == null
                            ? null
                            : () => onReactionTap!(entry.key),
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: entry.value.any((r) => r.userId == myId)
                                ? AppColors.teal.withValues(alpha: 0.15)
                                : AppColors.paper,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            '${entry.key} ${entry.value.length}',
                            style: theme.textTheme.labelSmall,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _textContent(ThemeData theme) {
    if (message.kind == 'sticker' && message.stickerPath != null) {
      return CachedNetworkImage(
        imageUrl: Supabase.instance.client.storage
            .from('stickers')
            .getPublicUrl(message.stickerPath!),
        cacheKey: message.stickerPath,
        width: 140,
        height: 140,
        fit: BoxFit.contain,
        errorWidget: (_, _, _) =>
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

  String _kindLabel(String kind) {
    return switch (kind) {
      'sticker' => '[figurinha]',
      'gif' => '[GIF]',
      'image' => '[imagem]',
      'video' => '[video]',
      'file' => '[arquivo]',
      _ => '',
    };
  }
}

String _formatTime(DateTime date) {
  final local = date.toLocal();
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}

class _MembersDialog extends ConsumerWidget {
  const _MembersDialog({required this.conversationId});

  final String conversationId;

  Future<void> _addMembers(BuildContext context, WidgetRef ref) async {
    final members = await ref.read(chatMembersProvider(conversationId).future);
    final connections = await ref.read(connectionsProvider.future);
    final existing = members.map((m) => m.userId).toSet();
    final selected = <String>{};
    if (!context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Adicionar membros'),
          content: SizedBox(
            width: double.maxFinite,
            height: 360,
            child:
                connections.accepted
                    .where((c) => !existing.contains(c.userId))
                    .toList()
                    .isEmpty
                ? const Center(child: Text('Nenhuma conexao disponivel.'))
                : ListView(
                    children: [
                      for (final c in connections.accepted)
                        if (!existing.contains(c.userId))
                          CheckboxListTile(
                            value: selected.contains(c.userId),
                            title: Text(c.displayName),
                            onChanged: (value) {
                              setDialogState(() {
                                if (value == true) {
                                  selected.add(c.userId);
                                } else {
                                  selected.remove(c.userId);
                                }
                              });
                            },
                          ),
                    ],
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, selected.isNotEmpty),
              child: const Text('Adicionar'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;

    try {
      await ref
          .read(chatRepositoryProvider)
          .addMembers(conversationId, selected.toList());
      ref.invalidate(chatMembersProvider(conversationId));
      ref.invalidate(conversationsProvider);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nao foi possivel adicionar.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(chatMembersProvider(conversationId));
    final myId = Supabase.instance.client.auth.currentUser?.id;

    return AlertDialog(
      title: const Text('Participantes'),
      content: SizedBox(
        width: double.maxFinite,
        height: 360,
        child: membersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const Text('Erro ao carregar.'),
          data: (members) {
            final isOwner = members.any(
              (m) => m.userId == myId && m.role == 'owner',
            );
            return ListView(
              children: [
                if (isOwner)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => _addMembers(context, ref),
                      icon: const Icon(Icons.person_add_outlined),
                      label: const Text('Adicionar'),
                    ),
                  ),
                for (final m in members)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.person_outline),
                    title: Text(m.displayName),
                    subtitle: m.role == 'owner'
                        ? const Text('Criador do grupo')
                        : null,
                    trailing: isOwner && m.userId != myId
                        ? IconButton(
                            tooltip: 'Remover',
                            onPressed: () async {
                              try {
                                await ref
                                    .read(chatRepositoryProvider)
                                    .removeMember(conversationId, m.userId);
                                ref.invalidate(
                                  chatMembersProvider(conversationId),
                                );
                                ref.invalidate(conversationsProvider);
                              } catch (_) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Nao foi possivel remover.',
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.remove_circle_outline),
                          )
                        : null,
                  ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fechar'),
        ),
      ],
    );
  }
}
