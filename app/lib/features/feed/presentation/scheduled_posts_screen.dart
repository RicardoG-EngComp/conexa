import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/feed_providers.dart';

class ScheduledPostsScreen extends ConsumerStatefulWidget {
  const ScheduledPostsScreen({super.key});

  @override
  ConsumerState<ScheduledPostsScreen> createState() =>
      _ScheduledPostsScreenState();
}

class _ScheduledPostsScreenState extends ConsumerState<ScheduledPostsScreen> {
  bool _drafts = false;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(feedRepositoryProvider);
      final items = _drafts
          ? await repo.fetchDrafts()
          : await repo.fetchScheduledPosts();
      if (!mounted) return;
      setState(() => _items = items);
    } catch (_) {
      if (mounted) setState(() => _error = 'Erro ao carregar.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteDraft(String id) async {
    await ref.read(feedRepositoryProvider).deleteDraft(id);
    await _load();
  }

  Future<void> _cancel(String id) async {
    try {
      await ref.read(feedRepositoryProvider).cancelScheduledPost(id);
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nao foi possivel cancelar.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Rascunhos e agendados')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Agendados')),
                ButtonSegment(value: true, label: Text('Rascunhos')),
              ],
              selected: {_drafts},
              onSelectionChanged: (values) {
                setState(() {
                  _drafts = values.first;
                  _items = [];
                });
                _load();
              },
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(child: Text(_error!))
                : _items.isEmpty
                ? Center(
                    child: Text(
                      _drafts
                          ? 'Nenhum rascunho.'
                          : 'Nenhuma publicacao agendada.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    itemCount: _items.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final payload =
                          (item['payload'] as Map?)?.cast<String, dynamic>() ??
                          const <String, dynamic>{};
                      final content = (payload['content'] as String?) ?? '';
                      if (_drafts) {
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            content,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Usar',
                                onPressed: () => context.push(
                                  '/feed/compose',
                                  extra: payload,
                                ),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                tooltip: 'Apagar',
                                onPressed: () =>
                                    _deleteDraft(item['id'] as String),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                        );
                      }

                      final scheduledAt = DateTime.parse(
                        item['scheduled_at'] as String,
                      );
                      final status = (item['status'] as String?) ?? 'pending';
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          content,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '$status · ${_date(scheduledAt)}'
                          '${item['error'] == null ? '' : ' · ${item['error']}'}',
                        ),
                        trailing: status == 'pending'
                            ? TextButton(
                                onPressed: () => _cancel(item['id'] as String),
                                child: const Text('Cancelar'),
                              )
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

String _date(DateTime value) {
  final local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)} ${two(local.hour)}:${two(local.minute)}';
}
