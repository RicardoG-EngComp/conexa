import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/feed_providers.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(myAnalyticsProvider);
    final viewsAsync = ref.watch(myViewsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            const Center(child: Text('Erro ao carregar insights.')),
        data: (data) {
          final viewsData = viewsAsync.asData?.value;
          final top = (data['top_posts'] as List? ?? const [])
              .cast<Map<String, dynamic>>();
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(myAnalyticsProvider);
              await ref.read(myAnalyticsProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Text(
                  'Ultimos ${data['days'] ?? 30} dias',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _Metric(
                      label: 'Publicacoes',
                      value: data['posts'],
                      icon: Icons.edit_outlined,
                    ),
                    _Metric(
                      label: 'Curtidas',
                      value: data['likes'],
                      icon: Icons.favorite_border,
                    ),
                    _Metric(
                      label: 'Respostas',
                      value: data['comments'],
                      icon: Icons.chat_bubble_outline,
                    ),
                    _Metric(
                      label: 'Republicacoes',
                      value: data['reposts'],
                      icon: Icons.repeat,
                    ),
                    _Metric(
                      label: 'Salvamentos',
                      value: data['bookmarks'],
                      icon: Icons.bookmark_outline,
                    ),
                    _Metric(
                      label: 'Votos em enquetes',
                      value: data['poll_votes'],
                      icon: Icons.poll_outlined,
                    ),
                    _Metric(
                      label: 'Views',
                      value: viewsData?['views'],
                      icon: Icons.visibility_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Principais publicacoes',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                if (top.isEmpty)
                  Text(
                    'Sem publicacoes no periodo.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                for (final item in top)
                  Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (item['preview'] as String?) ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${item['likes']} curtidas · '
                          '${item['comments']} respostas · '
                          '${item['reposts']} reposts · '
                          '${item['bookmarks']} salvos',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Metricas agregadas dos seus posts. Nao mostramos quem '
                  'interagiu nem dados demograficos.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.icon});

  final String label;
  final Object? value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 150,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.teal),
          const SizedBox(height: 6),
          Text('${value ?? 0}', style: theme.textTheme.headlineSmall),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
