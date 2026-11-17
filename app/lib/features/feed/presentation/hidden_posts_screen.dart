import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/feed_providers.dart';

class HiddenPostsScreen extends ConsumerWidget {
  const HiddenPostsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(hiddenPostsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Publicacoes ocultas')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Erro ao carregar.')),
        data: (posts) {
          if (posts.isEmpty) {
            return Center(
              child: Text(
                'Nenhuma publicacao ocultada.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.muted,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: posts.length,
            separatorBuilder: (_, _) => const Divider(),
            itemBuilder: (context, index) {
              final post = posts[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(post.content, maxLines: 2),
                subtitle: Text(post.authorName),
                trailing: TextButton(
                  onPressed: () async {
                    await ref
                        .read(feedRepositoryProvider)
                        .setNotInterested(post.id, false);
                    ref.invalidate(hiddenPostsProvider);
                    ref.invalidate(feedForYouProvider);
                    ref.invalidate(feedConnectionsProvider);
                  },
                  child: const Text('Mostrar de novo'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
