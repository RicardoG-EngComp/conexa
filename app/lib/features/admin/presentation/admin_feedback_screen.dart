import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/time_ago.dart';
import '../../reports/application/report_providers.dart';
import '../../feedback/application/feedback_providers.dart';
import '../../feedback/data/feedback_errors.dart';
import '../../feedback/data/feedback_models.dart';

class AdminFeedbackScreen extends ConsumerWidget {
  const AdminFeedbackScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdminAsync = ref.watch(isAdminProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Feedback')),
      body: SafeArea(
        child: isAdminAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) =>
              const Center(child: Text('Erro ao verificar acesso.')),
          data: (isAdmin) {
            if (!isAdmin) {
              return const Center(child: Text('Acesso restrito.'));
            }
            return const DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  TabBar(
                    tabs: [
                      Tab(text: 'Bugs'),
                      Tab(text: 'Sugestões'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _FeedbackList(kind: FeedbackKind.bug),
                        _FeedbackList(kind: FeedbackKind.suggestion),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FeedbackList extends ConsumerStatefulWidget {
  const _FeedbackList({required this.kind});

  final FeedbackKind kind;

  @override
  ConsumerState<_FeedbackList> createState() => _FeedbackListState();
}

class _FeedbackListState extends ConsumerState<_FeedbackList> {
  static const _groups = ['Abertos', 'Em andamento', 'Encerrados'];
  int _group = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final async = ref.watch(
      adminFeedbackProvider((kind: widget.kind, group: _group)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            0,
          ),
          child: Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (var i = 0; i < _groups.length; i++)
                ChoiceChip(
                  label: Text(_groups[i]),
                  selected: _group == i,
                  onSelected: (_) => setState(() => _group = i),
                ),
            ],
          ),
        ),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Não foi possível carregar o feedback.'),
                  TextButton(
                    onPressed: () => ref.invalidate(
                      adminFeedbackProvider((kind: widget.kind, group: _group)),
                    ),
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            ),
            data: (items) {
              if (items.isEmpty) {
                return Center(
                  child: Text(
                    'Nenhum feedback neste filtro.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: items.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final entry = items[index];
                  return _FeedbackAdminTile(
                    entry: entry,
                    onTap: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      showDragHandle: true,
                      builder: (_) => _FeedbackDetailSheet(entry: entry),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FeedbackAdminTile extends StatelessWidget {
  const _FeedbackAdminTile({required this.entry, required this.onTap});

  final FeedbackEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(
                entry.kind == FeedbackKind.bug
                    ? Icons.bug_report_outlined
                    : Icons.lightbulb_outline,
                color: AppColors.teal,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.title, style: theme.textTheme.titleSmall),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${entry.protocol} · ${entry.statusLabel} · '
                      '${timeAgo(entry.createdAt)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              if (entry.screenshotPath != null)
                const Padding(
                  padding: EdgeInsets.only(right: AppSpacing.xs),
                  child: Icon(
                    Icons.image_outlined,
                    size: 18,
                    color: AppColors.muted,
                  ),
                ),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedbackDetailSheet extends ConsumerStatefulWidget {
  const _FeedbackDetailSheet({required this.entry});

  final FeedbackEntry entry;

  @override
  ConsumerState<_FeedbackDetailSheet> createState() =>
      _FeedbackDetailSheetState();
}

class _FeedbackDetailSheetState extends ConsumerState<_FeedbackDetailSheet> {
  late String _status;
  String? _screenshotUrl;
  bool _loadingScreenshot = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _status = widget.entry.status;
    _loadScreenshot();
  }

  Future<void> _loadScreenshot() async {
    final path = widget.entry.screenshotPath;
    if (path == null) return;
    _loadingScreenshot = true;
    final url = await ref
        .read(feedbackRepositoryProvider)
        .signedScreenshotUrl(path);
    if (mounted) {
      setState(() {
        _screenshotUrl = url;
        _loadingScreenshot = false;
      });
    }
  }

  Future<void> _save() async {
    if (_status == widget.entry.status) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(feedbackRepositoryProvider)
          .updateStatus(widget.entry, _status);
      for (final group in [0, 1, 2]) {
        ref.invalidate(
          adminFeedbackProvider((kind: widget.entry.kind, group: group)),
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Status atualizado.')));
      Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() => _error = friendlyFeedbackError(error));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entry = widget.entry;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.protocol,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(entry.title, style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Enviado ${timeAgo(entry.createdAt)}'
                '${entry.platform == null ? '' : ' · ${entry.platform}'}'
                '${entry.appVersion == null || entry.appVersion!.isEmpty ? '' : ' · ${entry.appVersion}'}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _Field(label: 'Descrição', value: entry.description),
              if (entry.steps != null)
                _Field(label: 'Passos', value: entry.steps!),
              if (entry.expected != null)
                _Field(label: 'Esperado', value: entry.expected!),
              if (entry.actual != null)
                _Field(label: 'Aconteceu', value: entry.actual!),
              if (entry.problem != null)
                _Field(label: 'Problema', value: entry.problem!),
              if (entry.proposal != null)
                _Field(label: 'Proposta', value: entry.proposal!),
              if (entry.impact != null)
                _Field(label: 'Impacto', value: entry.impact!),
              if (entry.screenshotPath != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text('Print', style: theme.textTheme.titleSmall),
                const SizedBox(height: AppSpacing.sm),
                if (_loadingScreenshot)
                  const Center(child: CircularProgressIndicator())
                else if (_screenshotUrl == null)
                  Text(
                    'Print indisponível.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                    ),
                  )
                else
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: Image.network(
                      _screenshotUrl!,
                      height: 220,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
              ],
              const SizedBox(height: AppSpacing.lg),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: statusOptionsFor(entry.kind).entries
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.key,
                        child: Text(item.value),
                      ),
                    )
                    .toList(),
                onChanged: _saving
                    ? null
                    : (value) {
                        if (value != null) setState(() => _status = value);
                      },
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(_error!, style: const TextStyle(color: AppColors.danger)),
              ],
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Salvar status'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
