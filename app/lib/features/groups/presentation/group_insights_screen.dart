import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/group_providers.dart';

class GroupInsightsScreen extends ConsumerWidget {
  const GroupInsightsScreen({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(groupAnalyticsProvider(groupId));

    return Scaffold(
      appBar: AppBar(title: const Text('Insights do grupo')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            const Center(child: Text('Erro ao carregar insights.')),
        data: (data) => ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(
              'Ultimos 30 dias',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _Metric(label: 'Membros', value: data['members']),
                _Metric(label: 'Seguidores', value: data['followers']),
                _Metric(label: 'Posts', value: data['posts_30d']),
                _Metric(label: 'Respostas', value: data['comments_30d']),
                _Metric(label: 'Curtidas', value: data['likes_30d']),
                _Metric(label: 'Mensagens', value: data['messages_30d']),
                _Metric(
                  label: 'Eventos futuros',
                  value: data['events_upcoming'],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Metricas agregadas do grupo. Nao mostramos quem interagiu.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final Object? value;

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
