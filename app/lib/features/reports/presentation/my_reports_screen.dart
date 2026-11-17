import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/time_ago.dart';
import '../application/report_providers.dart';
import '../data/report_models.dart';
import 'report_dialog.dart';

const Map<String, String> _statusLabels = {
  'open': 'Recebida',
  'reviewing': 'Em analise',
  'resolved': 'Encerrada',
  'dismissed': 'Encerrada sem acao',
};

const Map<String, String> _appealLabels = {
  'none': 'Sem apelacao',
  'pending': 'Apelacao em analise',
  'accepted': 'Apelacao aceita',
  'rejected': 'Apelacao recusada',
};

class MyReportsScreen extends ConsumerWidget {
  const MyReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(myReportsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Meus relatos')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Erro ao carregar relatos.')),
        data: (reports) {
          if (reports.isEmpty) {
            return Center(
              child: Text(
                'Voce ainda nao enviou denuncias.',
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
                'Acompanhe o status e, se necessario, envie uma apelacao.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              for (final report in reports)
                _ReportTile(
                  report: report,
                  onAppeal: () => _showAppealDialog(context, ref, report),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showAppealDialog(
    BuildContext context,
    WidgetRef ref,
    Report report,
  ) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apelar da decisao'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Explique por que a decisao deve ser revista. A apelacao e unica.',
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: controller,
              minLines: 4,
              maxLines: 8,
              maxLength: 2000,
              decoration: const InputDecoration(
                labelText: 'Motivo da apelacao',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.length < 10) return;
              Navigator.pop(ctx, text);
            },
            child: const Text('Enviar apelacao'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null) return;

    try {
      await ref.read(reportRepositoryProvider).submitAppeal(report.id, reason);
      ref.invalidate(myReportsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Apelacao enviada para analise.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nao foi possivel enviar a apelacao.')),
        );
      }
    }
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({required this.report, required this.onAppeal});

  final Report report;
  final VoidCallback onAppeal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final category = reportCategories[report.category] ?? report.category;
    final canAppeal =
        (report.status == 'resolved' || report.status == 'dismissed') &&
        (report.appealStatus == 'none' || report.appealStatus == 'rejected');

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
                timeAgo(report.createdAt),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Status: ${_statusLabels[report.status] ?? report.status}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _appealLabels[report.appealStatus] ?? report.appealStatus,
            style: theme.textTheme.bodySmall?.copyWith(
              color: report.appealStatus == 'pending'
                  ? AppColors.teal
                  : AppColors.muted,
            ),
          ),
          if (report.actionTaken != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Acao: ${report.actionTaken}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.muted,
              ),
            ),
          ],
          if (report.appealResult != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text('Resultado: ${report.appealResult}'),
          ],
          if (canAppeal) ...[
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(onPressed: onAppeal, child: const Text('Apelar')),
          ],
        ],
      ),
    );
  }
}
