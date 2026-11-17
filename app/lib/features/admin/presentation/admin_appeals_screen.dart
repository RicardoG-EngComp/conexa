import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../reports/application/report_providers.dart';
import '../../reports/presentation/report_dialog.dart';

class AdminAppealsScreen extends ConsumerWidget {
  const AdminAppealsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(pendingAppealsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Apelacoes')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Erro ao carregar.')),
        data: (reports) {
          if (reports.isEmpty) {
            return const Center(child: Text('Nenhuma apelacao pendente.'));
          }
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text(
                'Apelacoes pendentes (${reports.length})',
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              for (final report in reports)
                Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
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
                        reportCategories[report.category] ?? report.category,
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (report.contentSnapshot != null)
                        Text(
                          report.contentSnapshot!,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (report.description != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text('Relato: ${report.description}'),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Apelacao: ${report.appealReason ?? ''}',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        children: [
                          OutlinedButton(
                            onPressed: () async {
                              await ref
                                  .read(reportRepositoryProvider)
                                  .resolveAppeal(
                                    reportId: report.id,
                                    accept: false,
                                    result: 'Apelacao recusada.',
                                  );
                              ref.invalidate(pendingAppealsProvider);
                            },
                            child: const Text('Recusar'),
                          ),
                          FilledButton(
                            onPressed: () async {
                              await ref
                                  .read(reportRepositoryProvider)
                                  .resolveAppeal(
                                    reportId: report.id,
                                    accept: true,
                                    result: 'Apelacao aceita.',
                                  );
                              ref.invalidate(pendingAppealsProvider);
                            },
                            child: const Text('Aceitar'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
