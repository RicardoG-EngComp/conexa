import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/report_providers.dart';

const Map<String, String> reportCategories = {
  'intolerancia_discriminacao': 'Intolerancia ou discriminacao',
  'violencia_ameaca': 'Violencia ou ameaca',
  'conteudo_sexual_explicito': 'Conteudo sexual explicito',
  'assedio': 'Assedio',
  'imagem_nao_consentida': 'Imagem intima sem consentimento',
  'menor_de_idade': 'Envolvendo menor de idade',
  'spam_golpe': 'Spam ou golpe',
  'perfil_falso': 'Perfil falso',
  'outro': 'Outro',
};

Future<void> showReportDialog(
  BuildContext context,
  WidgetRef ref, {
  required String reportedUserId,
  required String targetType,
  String? targetId,
  String? contentSnapshot,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _ReportDialog(
      reportedUserId: reportedUserId,
      targetType: targetType,
      targetId: targetId,
      contentSnapshot: contentSnapshot,
      ref: ref,
    ),
  );
}

class _ReportDialog extends StatefulWidget {
  const _ReportDialog({
    required this.reportedUserId,
    required this.targetType,
    required this.ref,
    this.targetId,
    this.contentSnapshot,
  });

  final String reportedUserId;
  final String targetType;
  final String? targetId;
  final String? contentSnapshot;
  final WidgetRef ref;

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  String _category = 'assedio';
  final _description = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.ref
          .read(reportRepositoryProvider)
          .submit(
            reportedUserId: widget.reportedUserId,
            targetType: widget.targetType,
            targetId: widget.targetId,
            category: _category,
            description: _description.text.trim().isEmpty
                ? null
                : _description.text.trim(),
            contentSnapshot: widget.contentSnapshot,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Denuncia enviada para analise.')),
      );
    } catch (_) {
      setState(() => _error = 'Nao foi possivel enviar a denuncia.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Denunciar'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Motivo'),
            items: reportCategories.entries
                .map(
                  (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                )
                .toList(),
            onChanged: (v) => setState(() => _category = v ?? 'outro'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _description,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Descreva (opcional)'),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.danger,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Enviar'),
        ),
      ],
    );
  }
}
