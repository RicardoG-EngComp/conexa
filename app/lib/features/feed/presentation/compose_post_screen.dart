import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/moderation_errors.dart';
import '../../../core/errors/moderation_ui.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../groups/application/group_providers.dart';
import '../../groups/data/group_models.dart';
import '../application/feed_providers.dart';
import '../data/feed_models.dart';

class ComposePostScreen extends ConsumerStatefulWidget {
  const ComposePostScreen({super.key, this.quoted, this.groupId});

  final FeedPost? quoted;
  final String? groupId;

  @override
  ConsumerState<ComposePostScreen> createState() => _ComposePostScreenState();
}

class _ComposePostScreenState extends ConsumerState<ComposePostScreen> {
  final _text = TextEditingController();
  String _visibility = 'public';
  String? _courseTopicId;
  String? _campusTopicId;
  final Set<String> _eventTopicIds = {};
  String? _roleId;
  bool _postedAsGroup = false;
  bool _posting = false;

  bool get _groupMode => widget.groupId != null;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _toggleEvent(String id, int selectedCount) {
    if (_eventTopicIds.contains(id)) {
      setState(() => _eventTopicIds.remove(id));
      return;
    }
    if (selectedCount >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escolha no máximo 3 categorias de evento.')),
      );
      return;
    }
    setState(() => _eventTopicIds.add(id));
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
        const SnackBar(content: Text('Escolha um cargo para publicar no grupo.')),
      );
      return;
    }

    setState(() => _posting = true);
    try {
      await ref.read(feedRepositoryProvider).createPost(
        text,
        visibility: _groupMode ? 'public' : _visibility,
        topicIds: topicIds,
        groupId: _groupMode ? group?.id : null,
        roleId: roleId,
        postedAsGroup: _postedAsGroup,
        quotedPostId: widget.quoted?.id,
      );
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
    final topics = ref.watch(topicsProvider).asData?.value ?? const <FeedTopic>[];
    final groups = ref.watch(myGroupsProvider).asData?.value ?? const <UserGroup>[];

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
            onPressed: _posting ? null : () => _publish(
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
              onToggleAsGroup: (value) => setState(() => _postedAsGroup = value),
            ),
          if (_groupMode && group != null) const SizedBox(height: AppSpacing.md),
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
                        child: Text(c.label, maxLines: 1, overflow: TextOverflow.ellipsis),
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
                          onSelected: (_) => _toggleEvent(event.id, _eventTopicIds.length),
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
                    onChanged: (value) =>
                        setState(() => _roleId = value),
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
              const Icon(Icons.groups_outlined, size: 18, color: AppColors.teal),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  group.name,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              if (group.isOfficial)
                const Icon(Icons.verified, size: 16, color: AppColors.teal),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (canPostAsGroup)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Publicar em nome do grupo'),
              subtitle: const Text('O post aparece com o nome e o selo do grupo.'),
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
