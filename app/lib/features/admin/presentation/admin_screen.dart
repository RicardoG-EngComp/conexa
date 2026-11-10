import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../reports/application/report_providers.dart';
import '../../reports/data/report_models.dart';
import '../../reports/presentation/report_dialog.dart';

class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isAdminAsync = ref.watch(isAdminProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Administracao'),
        actions: [
          IconButton(
            tooltip: 'Materiais pendentes',
            icon: const Icon(Icons.menu_book_outlined),
            onPressed: () => context.push('/admin/studies'),
          ),
          IconButton(
            tooltip: 'Aprovar grupos',
            icon: const Icon(Icons.groups_outlined),
            onPressed: () => context.push('/admin/groups'),
          ),
          IconButton(
            tooltip: 'Insignias',
            icon: const Icon(Icons.military_tech_outlined),
            onPressed: () => context.push('/admin/badges'),
          ),
          IconButton(
            tooltip: 'Diagnostico de notificacoes',
            icon: const Icon(Icons.notifications_active_outlined),
            onPressed: () => context.push('/admin/notifications'),
          ),
        ],
      ),
      body: SafeArea(
        child: isAdminAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) =>
              const Center(child: Text('Erro ao verificar acesso.')),
          data: (isAdmin) {
            if (!isAdmin) {
              return const Center(child: Text('Acesso restrito.'));
            }
            final reportsAsync = ref.watch(openReportsProvider);
            return reportsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) =>
                  const Center(child: Text('Erro ao carregar denuncias.')),
              data: (reports) {
                if (reports.isEmpty) {
                  return Center(
                    child: Text(
                      'Nenhuma denuncia pendente.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                  );
                }
                return ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    Text(
                      'Denuncias abertas (${reports.length})',
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ...reports.map(
                      (report) => _ReportCard(
                        report: report,
                        onAction: (action) async {
                          await ref
                              .read(reportRepositoryProvider)
                              .review(
                                reportId: report.id,
                                reportedUserId: report.reportedUserId,
                                action: action,
                                targetType: report.targetType,
                                targetId:
                                    report.targetId ??
                                    (report.targetType == 'profile'
                                        ? report.reportedUserId
                                        : null),
                              );
                          ref.invalidate(openReportsProvider);
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report, required this.onAction});

  final Report report;
  final Future<void> Function(String action) onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final category = reportCategories[report.category] ?? report.category;
    return Container(
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
          Row(
            children: [
              Expanded(
                child: Text(category, style: theme.textTheme.titleSmall),
              ),
              Text(
                report.status,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Tipo: ${report.targetType}',
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
          ),
          if (report.contentSnapshot != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.paper,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(report.contentSnapshot!),
            ),
          ],
          if (report.description != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('Relato: ${report.description}'),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Denunciante: ${report.reporterId.substring(0, 8)}...  |  '
            'Denunciado: ${report.reportedUserId.substring(0, 8)}...',
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              OutlinedButton(
                onPressed: () => onAction('hide'),
                child: const Text('Ocultar'),
              ),
              OutlinedButton(
                onPressed: () => onAction('restore'),
                child: const Text('Restaurar'),
              ),
              OutlinedButton(
                onPressed: () => onAction('delete'),
                child: const Text('Remover'),
              ),
              OutlinedButton(
                onPressed: () => onAction('dismiss'),
                child: const Text('Ignorar'),
              ),
              OutlinedButton(
                onPressed: () => onAction('warn'),
                child: const Text('Advertir'),
              ),
              OutlinedButton(
                onPressed: () => onAction('suspend'),
                child: const Text('Suspender'),
              ),
              FilledButton(
                onPressed: () => onAction('ban'),
                child: const Text('Banir'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
