import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/errors/moderation_errors.dart';
import '../../../core/errors/moderation_ui.dart';
import '../../../core/media/image_processor.dart';
import '../../../core/media/media_models.dart';
import '../../../core/media/media_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/uuid.dart';
import '../../connections/application/connection_providers.dart';
import '../../groups/application/group_providers.dart';
import '../../groups/data/group_models.dart';
import '../application/feed_providers.dart';
import '../data/feed_models.dart';

class ComposePostScreen extends ConsumerStatefulWidget {
  const ComposePostScreen({
    super.key,
    this.quoted,
    this.groupId,
    this.initialText,
    this.initialDraft,
  });

  final FeedPost? quoted;
  final String? groupId;
  final String? initialText;
  final Map<String, dynamic>? initialDraft;

  @override
  ConsumerState<ComposePostScreen> createState() => _ComposePostScreenState();
}

class _ComposePostScreenState extends ConsumerState<ComposePostScreen> {
  final _text = TextEditingController();
  final _picker = ImagePicker();
  final List<FeedMediaDraft> _media = [];
  final List<TextEditingController> _pollOptions = [
    TextEditingController(),
    TextEditingController(),
  ];
  final Set<String> _mentionIds = {};
  final Map<String, String> _mentionNames = {};
  String _visibility = 'public';
  String _replyPolicy = 'anyone';
  String? _courseTopicId;
  String? _campusTopicId;
  final Set<String> _eventTopicIds = {};
  String? _roleId;
  bool _postedAsGroup = false;
  bool _posting = false;
  bool _showPoll = false;
  int _pollHours = 24;
  bool _uploadingMedia = false;
  bool _savingDraft = false;
  bool _scheduling = false;

  bool get _groupMode => widget.groupId != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialText;
    if (initial != null && initial.isNotEmpty) {
      _text.text = initial;
    }
    final draft = widget.initialDraft;
    if (draft != null) {
      _text.text = (draft['content'] as String?) ?? _text.text;
      _visibility = (draft['visibility'] as String?) ?? _visibility;
      _replyPolicy = (draft['reply_policy'] as String?) ?? _replyPolicy;
      final media = draft['media'];
      if (media is List) {
        _media.addAll(
          media
              .whereType<Map>()
              .map(
                (item) => FeedMediaDraft.fromMap(item.cast<String, dynamic>()),
              )
              .toList(),
        );
      }
    }
  }

  @override
  void dispose() {
    _text.dispose();
    for (final controller in _pollOptions) {
      controller.dispose();
    }
    super.dispose();
  }

  void _toggleEvent(String id, int selectedCount) {
    if (_eventTopicIds.contains(id)) {
      setState(() => _eventTopicIds.remove(id));
      return;
    }
    if (selectedCount >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Escolha no máximo 3 categorias de evento.'),
        ),
      );
      return;
    }
    setState(() => _eventTopicIds.add(id));
  }

  Future<void> _pickImages() async {
    if (_media.any((m) => m.kind == 'video')) {
      _showMessage('Remova o video para adicionar imagens.');
      return;
    }
    final remaining = 4 - _media.length;
    if (remaining <= 0) {
      _showMessage('Limite de 4 imagens.');
      return;
    }
    final picked = await _picker.pickMultiImage(imageQuality: 90);
    if (picked.isEmpty) return;

    setState(() => _uploadingMedia = true);
    try {
      for (final file in picked.take(remaining)) {
        final processed = await ImageProcessor.feedImage(
          await file.readAsBytes(),
        );
        final assetId = uuidV4();
        final media = ref.read(mediaServiceProvider);
        final full = await media.uploadImage(
          bytes: processed.full,
          kind: 'feed_image',
          variant: 'full',
          contentType: 'image/webp',
          assetId: assetId,
          width: processed.width,
          height: processed.height,
        );
        try {
          await media.uploadImage(
            bytes: processed.thumb,
            kind: 'feed_image',
            variant: 'thumb',
            contentType: 'image/webp',
            assetId: assetId,
            width: processed.thumbWidth,
            height: processed.thumbHeight,
          );
        } catch (_) {}
        _media.add(
          FeedMediaDraft(
            path: full.key,
            kind: 'image',
            mimeType: 'image/webp',
            byteSize: full.bytes,
            width: processed.width,
            height: processed.height,
            position: _media.length,
          ),
        );
      }
    } on MediaException catch (error) {
      _showMessage(_mediaError(error.code));
    } catch (_) {
      _showMessage('Nao foi possivel enviar a imagem.');
    } finally {
      if (mounted) setState(() => _uploadingMedia = false);
    }
  }

  void _setAlt(int index, String value) {
    final current = _media[index];
    final text = value.trim();
    setState(() {
      _media[index] = current.copyWith(
        altText: text.isEmpty ? null : text,
        clearAlt: text.isEmpty,
      );
    });
  }

  Future<void> _openMentions() async {
    final data = await ref.read(connectionsProvider.future);
    final selected = {..._mentionIds};
    if (!mounted) return;

    final result = await showDialog<Set<String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Mencionar conexoes'),
          content: SizedBox(
            width: double.maxFinite,
            height: 320,
            child: data.accepted.isEmpty
                ? const Center(child: Text('Nenhuma conexao aceita ainda.'))
                : ListView(
                    children: [
                      for (final connection in data.accepted)
                        CheckboxListTile(
                          value: selected.contains(connection.userId),
                          title: Text(connection.displayName),
                          onChanged: (value) {
                            setDialogState(() {
                              if (value == true) {
                                if (selected.length < 10) {
                                  selected.add(connection.userId);
                                }
                              } else {
                                selected.remove(connection.userId);
                              }
                            });
                          },
                        ),
                    ],
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, selected),
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;

    setState(() {
      _mentionIds
        ..clear()
        ..addAll(result);
      _mentionNames
        ..clear()
        ..addEntries(
          data.accepted
              .where((c) => result.contains(c.userId))
              .map((c) => MapEntry(c.userId, c.displayName)),
        );
    });
  }

  Map<String, dynamic> _payload(List<String> topicIds) {
    final poll = _showPoll
        ? {
            'options': _pollOptions
                .map((c) => c.text.trim())
                .where((text) => text.isNotEmpty)
                .toList(),
            'hours': _pollHours,
          }
        : null;
    return {
      'content': _text.text.trim(),
      'visibility': _groupMode ? 'public' : _visibility,
      'reply_policy': _replyPolicy,
      'topic_ids': topicIds,
      'mentions': _mentionIds.toList(),
      'media': _media.map((item) => item.toMap()).toList(),
      'poll': ?poll,
    };
  }

  Future<void> _saveDraft(List<String> topicIds) async {
    if (_text.text.trim().isEmpty) {
      _showMessage('Escreva algo para salvar o rascunho.');
      return;
    }
    setState(() => _savingDraft = true);
    try {
      await ref.read(feedRepositoryProvider).saveDraft(_payload(topicIds));
      if (mounted) {
        _showMessage('Rascunho salvo.');
        context.pop();
      }
    } catch (_) {
      _showMessage('Nao foi possivel salvar o rascunho.');
    } finally {
      if (mounted) setState(() => _savingDraft = false);
    }
  }

  Future<void> _schedule(List<String> topicIds) async {
    if (_text.text.trim().isEmpty) {
      _showMessage('Escreva algo para agendar.');
      return;
    }
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(hours: 1)),
      firstDate: now.add(const Duration(minutes: 5)),
      lastDate: now.add(const Duration(days: 30)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (time == null || !mounted) return;

    final scheduledAt = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() => _scheduling = true);
    try {
      await ref
          .read(feedRepositoryProvider)
          .schedulePost(_payload(topicIds), scheduledAt);
      if (mounted) {
        _showMessage('Publicacao agendada.');
        context.pop();
      }
    } catch (_) {
      _showMessage('Nao foi possivel agendar. Verifique a data.');
    } finally {
      if (mounted) setState(() => _scheduling = false);
    }
  }

  String _mediaError(String code) {
    return switch (code) {
      'quota_feed_imagens' => 'Limite diario de imagens atingido.',
      'quota_feed_videos' => 'Limite diario de videos atingido.',
      'quota_feed_bytes' => 'Limite mensal de midia atingido.',
      'arquivo_muito_grande' => 'Arquivo muito grande.',
      'tipo_ou_variante_invalida' => 'Formato nao suportado.',
      'conteudo_nao_confere_com_tipo' => 'Arquivo invalido.',
      _ => 'Nao foi possivel enviar a midia.',
    };
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _publish({
    required String? roleId,
    required UserGroup? group,
    required List<String> topicIds,
  }) async {
    final text = _text.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escreva algo para publicar.')),
      );
      return;
    }
    if (_groupMode && roleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Escolha um cargo para publicar no grupo.'),
        ),
      );
      return;
    }
    if (_uploadingMedia) {
      _showMessage('Aguarde o envio da midia terminar.');
      return;
    }
    final pollValues = _pollOptions
        .map((c) => c.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();
    if (_showPoll && pollValues.length < 2) {
      _showMessage('Adicione pelo menos 2 opcoes na enquete.');
      return;
    }

    setState(() => _posting = true);
    try {
      final postId = await ref
          .read(feedRepositoryProvider)
          .createPost(
            text,
            visibility: _groupMode ? 'public' : _visibility,
            replyPolicy: _replyPolicy,
            topicIds: topicIds,
            groupId: _groupMode ? group?.id : null,
            roleId: roleId,
            postedAsGroup: _postedAsGroup,
            quotedPostId: widget.quoted?.id,
          );

      if (_media.isNotEmpty) {
        try {
          await ref.read(feedRepositoryProvider).attachMedia(postId, _media);
        } catch (_) {
          _showMessage('Publicacao criada, mas a midia falhou.');
        }
      }
      if (_showPoll && pollValues.length >= 2) {
        try {
          await ref
              .read(feedRepositoryProvider)
              .createPoll(postId, pollValues, hours: _pollHours);
        } catch (_) {
          _showMessage('Publicacao criada, mas a enquete falhou.');
        }
      }
      if (_mentionIds.isNotEmpty) {
        try {
          await ref
              .read(feedRepositoryProvider)
              .setPostMentions(postId, _mentionIds.toList());
        } catch (_) {
          _showMessage('Publicacao criada, mas as mencoes falharam.');
        }
      }

      ref.invalidate(feedForYouProvider);
      ref.invalidate(feedConnectionsProvider);
      if (mounted) context.pop();
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
                  fallback: 'Nao foi possivel publicar.',
                ),
              ),
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topics =
        ref.watch(topicsProvider).asData?.value ?? const <FeedTopic>[];
    final groups =
        ref.watch(myGroupsProvider).asData?.value ?? const <UserGroup>[];

    final courses = topics.where((t) => t.isCourse).toList();
    final campuses = topics.where((t) => t.isCampus).toList();
    final events = topics.where((t) => t.isEvent).toList();

    UserGroup? group;
    if (_groupMode) {
      for (final g in groups) {
        if (g.id == widget.groupId) {
          group = g;
          break;
        }
      }
    }

    final groupRoles = group?.roles ?? const <UserGroupRole>[];
    final sealRoles = <({UserGroupRole role, String groupName})>[];
    for (final g in groups) {
      if (g.isPublicVerified) {
        for (final r in g.roles) {
          sealRoles.add((role: r, groupName: g.name));
        }
      }
    }

    final effectiveRoleId = _groupMode
        ? (_roleId ?? (groupRoles.isNotEmpty ? groupRoles.first.id : null))
        : _roleId;
    final canPostAsGroup = _groupMode && (group?.canPostAsGroup ?? false);

    final topicIds = <String>[
      ?_courseTopicId,
      ?_campusTopicId,
      ..._eventTopicIds,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('Publicar', style: theme.textTheme.titleLarge),
        actions: [
          TextButton(
            onPressed: _posting
                ? null
                : () => _publish(
                    roleId: effectiveRoleId,
                    group: group,
                    topicIds: topicIds,
                  ),
            child: _posting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Publicar'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          if (_groupMode && group != null)
            _GroupContextBanner(
              group: group,
              canPostAsGroup: canPostAsGroup,
              postedAsGroup: _postedAsGroup,
              onToggleAsGroup: (value) =>
                  setState(() => _postedAsGroup = value),
            ),
          if (_groupMode && group != null)
            const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: TextField(
              controller: _text,
              minLines: 4,
              maxLines: 8,
              maxLength: 2000,
              decoration: const InputDecoration(
                hintText: 'O que você quer compartilhar?',
                border: InputBorder.none,
                counterText: '',
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _Section(
            title: 'Midia',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _uploadingMedia ? null : _pickImages,
                      icon: const Icon(Icons.image_outlined, size: 18),
                      label: const Text('Imagem'),
                    ),
                    if (_uploadingMedia) ...[
                      const SizedBox(width: AppSpacing.md),
                      const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Ate 4 imagens. Imagens sao comprimidas no aparelho.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
                for (var i = 0; i < _media.length; i++) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.paper,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _media[i].kind == 'video'
                                  ? Icons.videocam_outlined
                                  : Icons.image_outlined,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _media[i].kind == 'video'
                                    ? 'Video'
                                    : 'Imagem ${i + 1}',
                                style: theme.textTheme.labelMedium,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Remover',
                              onPressed: () =>
                                  setState(() => _media.removeAt(i)),
                              icon: const Icon(Icons.close, size: 18),
                            ),
                          ],
                        ),
                        TextField(
                          maxLength: 300,
                          decoration: const InputDecoration(
                            labelText: 'Descricao (alt)',
                            counterText: '',
                          ),
                          onChanged: (value) => _setAlt(i, value),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _Section(
            title: 'Enquete',
            child: _showPoll
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < _pollOptions.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: TextField(
                            controller: _pollOptions[i],
                            maxLength: 80,
                            decoration: InputDecoration(
                              labelText: 'Opcao ${i + 1}',
                              counterText: '',
                              suffixIcon: _pollOptions.length > 2
                                  ? IconButton(
                                      onPressed: () => setState(() {
                                        _pollOptions.removeAt(i).dispose();
                                      }),
                                      icon: const Icon(Icons.close, size: 18),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      Row(
                        children: [
                          if (_pollOptions.length < 4)
                            TextButton.icon(
                              onPressed: () => setState(
                                () => _pollOptions.add(TextEditingController()),
                              ),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Opcao'),
                            ),
                          const Spacer(),
                          DropdownButton<int>(
                            value: _pollHours,
                            items: const [
                              DropdownMenuItem(value: 24, child: Text('24h')),
                              DropdownMenuItem(
                                value: 72,
                                child: Text('3 dias'),
                              ),
                              DropdownMenuItem(
                                value: 168,
                                child: Text('7 dias'),
                              ),
                            ],
                            onChanged: (value) =>
                                setState(() => _pollHours = value ?? 24),
                          ),
                        ],
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => setState(() => _showPoll = false),
                          child: const Text('Remover enquete'),
                        ),
                      ),
                    ],
                  )
                : Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () => setState(() => _showPoll = true),
                      icon: const Icon(Icons.poll_outlined, size: 18),
                      label: const Text('Adicionar enquete'),
                    ),
                  ),
          ),
          const SizedBox(height: AppSpacing.md),
          _Section(
            title: 'Mencoes',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _openMentions,
                    icon: const Icon(Icons.alternate_email, size: 18),
                    label: const Text('Mencionar conexoes'),
                  ),
                ),
                if (_mentionIds.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final id in _mentionIds)
                        InputChip(
                          label: Text(_mentionNames[id] ?? 'Conexao'),
                          onDeleted: () => setState(() {
                            _mentionIds.remove(id);
                            _mentionNames.remove(id);
                          }),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _Section(
            title: 'Quem pode ver',
            child: _groupMode
                ? Text(
                    'Membros do grupo. Posts de grupo público também aparecem '
                    'para seguidores no feed Conexão.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                      height: 1.4,
                    ),
                  )
                : SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'public',
                        label: Text('Público'),
                        icon: Icon(Icons.public, size: 16),
                      ),
                      ButtonSegment(
                        value: 'friends',
                        label: Text('Conexões'),
                        icon: Icon(Icons.people_outline, size: 16),
                      ),
                    ],
                    selected: {_visibility},
                    onSelectionChanged: (values) =>
                        setState(() => _visibility = values.first),
                  ),
          ),
          const SizedBox(height: AppSpacing.md),
          _Section(
            title: 'Quem pode responder',
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'anyone',
                  label: Text('Todos que veem'),
                  icon: Icon(Icons.forum_outlined, size: 16),
                ),
                ButtonSegment(
                  value: 'connections',
                  label: Text('Só conexões'),
                  icon: Icon(Icons.people_outline, size: 16),
                ),
              ],
              selected: {_replyPolicy},
              onSelectionChanged: (values) =>
                  setState(() => _replyPolicy = values.first),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _Section(
            title: 'Tópicos',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String?>(
                  initialValue: _courseTopicId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Curso'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Nenhum curso'),
                    ),
                    ...courses.map(
                      (c) => DropdownMenuItem<String?>(
                        value: c.id,
                        child: Text(
                          c.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _courseTopicId = value),
                ),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<String?>(
                  initialValue: _campusTopicId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Campus'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Nenhum campus'),
                    ),
                    ...campuses.map(
                      (c) => DropdownMenuItem<String?>(
                        value: c.id,
                        child: Text(c.label),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _campusTopicId = value),
                ),
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Categorias de evento',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: events
                      .map(
                        (event) => FilterChip(
                          label: Text(event.label),
                          selected: _eventTopicIds.contains(event.id),
                          onSelected: (_) =>
                              _toggleEvent(event.id, _eventTopicIds.length),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          if (_groupMode && groupRoles.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _Section(
              title: 'Cargo',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    key: ValueKey('role-$effectiveRoleId'),
                    initialValue: effectiveRoleId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Cargo'),
                    items: groupRoles
                        .map(
                          (r) => DropdownMenuItem<String>(
                            value: r.id,
                            child: Text(r.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _roleId = value),
                  ),
                  if (!canPostAsGroup)
                    Text(
                      'Seu cargo não permite publicar em nome do grupo.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                        height: 1.4,
                      ),
                    ),
                ],
              ),
            ),
          ] else if (!_groupMode && sealRoles.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _Section(
              title: 'Selo de cargo',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String?>(
                    key: ValueKey('seal-${_roleId ?? 'none'}'),
                    initialValue: _roleId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Cargo'),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Sem selo'),
                      ),
                      ...sealRoles.map(
                        (s) => DropdownMenuItem<String?>(
                          value: s.role.id,
                          child: Text(
                            '${s.role.name} · ${s.groupName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() => _roleId = value),
                  ),
                  Text(
                    'Só cargos de grupos públicos verificados. O selo não muda '
                    'quem vê o post.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (widget.quoted != null) ...[
            const SizedBox(height: AppSpacing.md),
            _Section(
              title: 'Citando uma publicação',
              child: _QuotedPreview(post: widget.quoted!),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _savingDraft || _posting || _scheduling
                      ? null
                      : () => _saveDraft(topicIds),
                  icon: _savingDraft
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Salvar rascunho'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _scheduling || _posting || _savingDraft
                      ? null
                      : () => _schedule(topicIds),
                  icon: _scheduling
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.schedule, size: 18),
                  label: const Text('Agendar'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _GroupContextBanner extends StatelessWidget {
  const _GroupContextBanner({
    required this.group,
    required this.canPostAsGroup,
    required this.postedAsGroup,
    required this.onToggleAsGroup,
  });

  final UserGroup group;
  final bool canPostAsGroup;
  final bool postedAsGroup;
  final void Function(bool) onToggleAsGroup;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
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
              Icon(Icons.groups_outlined, size: 18, color: AppColors.teal),
              const SizedBox(width: 8),
              Expanded(
                child: Text(group.name, style: theme.textTheme.titleSmall),
              ),
              if (group.isOfficial)
                Icon(Icons.verified, size: 16, color: AppColors.teal),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (canPostAsGroup)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Publicar em nome do grupo'),
              subtitle: const Text(
                'O post aparece com o nome e o selo do grupo.',
              ),
              value: postedAsGroup,
              onChanged: onToggleAsGroup,
            ),
        ],
      ),
    );
  }
}

class _QuotedPreview extends StatelessWidget {
  const _QuotedPreview({required this.post});

  final FeedPost post;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(post.authorName, style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            post.content,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.muted,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}
