import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'update_info.dart';
import 'update_service.dart';

class UpdateScreen extends StatefulWidget {
  const UpdateScreen({super.key, required this.info, required this.service});

  final UpdateInfo info;
  final UpdateService service;

  @override
  State<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends State<UpdateScreen> {
  bool _downloading = false;
  double _progress = 0;
  String? _error;

  Future<void> _update() async {
    setState(() {
      _downloading = true;
      _error = null;
      _progress = 0;
    });
    try {
      await widget.service.downloadAndInstall(
        widget.info,
        onProgress: (value) {
          if (mounted) setState(() => _progress = value);
        },
      );
      if (mounted) setState(() => _downloading = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Nao foi possivel atualizar. Tente novamente.';
          _downloading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              const Icon(Icons.system_update, size: 56),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Atualizacao obrigatoria',
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'A versao ${widget.info.version} esta disponivel. '
                'Atualize para continuar usando o app.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppColors.muted,
                ),
              ),
              if (widget.info.notes.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(widget.info.notes),
                ),
              ],
              if (_downloading) ...[
                const SizedBox(height: AppSpacing.lg),
                LinearProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text('${(_progress * 100).toStringAsFixed(0)}%'),
              ],
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  _error!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.danger,
                  ),
                ),
              ],
              const Spacer(),
              FilledButton(
                onPressed: _downloading ? null : _update,
                child: _downloading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Atualizar agora'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
