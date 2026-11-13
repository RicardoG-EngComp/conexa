import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/time_ago.dart';
import '../application/feedback_providers.dart';
import '../data/feedback_models.dart';

class FeedbackScreen extends ConsumerWidget {
  const FeedbackScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Feedback')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(
              'Ajude a melhorar o Conexa',
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Encontrou um problema ou pensou em algo que deixaria o app '
              'melhor? Envie para a equipe. Você acompanha o status por aqui.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _FeedbackOption(
              icon: Icons.bug_report_outlined,
              title: 'Reportar um problema',
              subtitle: 'Algo não funcionou como deveria.',
              onTap: () => context.push('/feedback/bug'),
            ),
            const SizedBox(height: AppSpacing.md),
            _FeedbackOption(
              icon: Icons.lightbulb_outline,
              title: 'Enviar uma sugestão',
              subtitle: 'Uma ideia de função ou melhoria.',
              onTap: () => context.push('/feedback/suggestion'),
            ),
            const Divider(height: AppSpacing.xl),
            Text('Meus envios', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.md),
            ref
                .watch(myFeedbackProvider)
                .when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (_, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Não foi possível carregar seus envios.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                      TextButton(
                        onPressed: () => ref.invalidate(myFeedbackProvider),
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                  data: (items) {
                    if (items.isEmpty) {
                      return Text(
                        'Você ainda não enviou nenhum feedback.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.muted,
                        ),
                      );
                    }
                    return Column(
                      children: items
                          .map((entry) => _FeedbackTile(entry: entry))
                          .toList(growable: false),
                    );
                  },
                ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Não envie dados sensíveis (senhas, documentos ou dados de '
              'terceiros). O print é opcional.',
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

class _FeedbackOption extends StatelessWidget {
  const _FeedbackOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
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
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.paper,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(icon, color: AppColors.teal),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleSmall),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                  ],
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

class _FeedbackTile extends StatelessWidget {
  const _FeedbackTile({required this.entry});

  final FeedbackEntry entry;

  Color get _statusColor => switch (entry.status) {
    'fixed' || 'implemented' => AppColors.success,
    'wontfix' || 'declined' => AppColors.danger,
    'in_progress' || 'accepted' => AppColors.teal,
    _ => AppColors.muted,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
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
          Row(
            children: [
              Icon(
                entry.kind == FeedbackKind.bug
                    ? Icons.bug_report_outlined
                    : Icons.lightbulb_outline,
                size: 18,
                color: AppColors.teal,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                entry.protocol,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.muted,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  entry.statusLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: _statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(entry.title, style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Enviado ${timeAgo(entry.createdAt)}',
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
