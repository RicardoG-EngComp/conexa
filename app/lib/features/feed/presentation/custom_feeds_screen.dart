import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/feed_providers.dart';

class CustomFeedsScreen extends ConsumerWidget {
  const CustomFeedsScreen({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final topics = await ref.read(topicsProvider.future);
    if (!context.mounted) return;
    final name = TextEditingController();
    final selected = <String>{};
    final result = await showDialog<({String name, Set<String> topics})>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Novo feed'),
          content: SizedBox(
            width: double.maxFinite,
            height: 420,
            child: Column(
              children: [
                TextField(
                  controller: name,
                  maxLength: 40,
                  decoration: const InputDecoration(labelText: 'Nome'),
                ),
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Escolha ate 5 topicos',
                    style: Theme.of(ctx).textTheme.labelMedium,
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      for (final topic in topics)
                        CheckboxListTile(
                          dense: true,
                          value: selected.contains(topic.id),
                          title: Text(topic.label),
                          onChanged: (value) {
                            setDialogState(() {
                              if (value == true) {
                                if (selected.length < 5) {
                                  selected.add(topic.id);
                                }
                              } else {
                                selected.remove(topic.id);
                              }
                            });
                          },
                        ),
                    ],
                  ),
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
              onPressed: () {
                final text = name.text.trim();
                if (text.length < 3 || selected.isEmpty) return;
                Navigator.pop(ctx, (name: text, topics: selected));
              },
              child: const Text('Criar'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    if (result == null) return;

    try {
      await ref
          .read(feedRepositoryProvider)
          .createCustomFeed(result.name, result.topics.toList());
      ref.invalidate(customFeedsProvider);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nao foi possivel criar o feed.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(customFeedsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feeds personalizados'),
        actions: [
          IconButton(
            tooltip: 'Novo feed',
            onPressed: () => _create(context, ref),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Erro ao carregar feeds.')),
        data: (feeds) {
          if (feeds.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  'Crie um feed com ate 5 topicos para acompanhar apenas o '
                  'que interessa.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: feeds.length,
            separatorBuilder: (_, _) => const Divider(),
            itemBuilder: (context, index) {
              final feed = feeds[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.filter_list),
                title: Text(feed.name),
                subtitle: Text('${feed.topicIds.length} topicos'),
                trailing: IconButton(
                  tooltip: 'Apagar',
                  onPressed: () async {
                    await ref
                        .read(feedRepositoryProvider)
                        .deleteCustomFeed(feed.id);
                    ref.invalidate(customFeedsProvider);
                  },
                  icon: const Icon(Icons.delete_outline),
                ),
                onTap: () =>
                    context.push('/feed/feeds/${feed.id}', extra: feed),
              );
            },
          );
        },
      ),
    );
  }
}
