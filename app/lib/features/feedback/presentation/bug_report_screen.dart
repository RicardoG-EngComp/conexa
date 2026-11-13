import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/feedback_providers.dart';
import '../data/feedback_errors.dart';

class BugReportScreen extends ConsumerStatefulWidget {
  const BugReportScreen({super.key});

  @override
  ConsumerState<BugReportScreen> createState() => _BugReportScreenState();
}

class _BugReportScreenState extends ConsumerState<BugReportScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _steps = TextEditingController();
  final _expected = TextEditingController();
  final _actual = TextEditingController();
  final _device = TextEditingController();
  final _picker = ImagePicker();

  Uint8List? _screenshot;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _steps.dispose();
    _expected.dispose();
    _actual.dispose();
    _device.dispose();
    super.dispose();
  }

  String get _platform {
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'Android',
      TargetPlatform.iOS => 'iOS',
      TargetPlatform.macOS => 'macOS',
      TargetPlatform.windows => 'Windows',
      TargetPlatform.linux => 'Linux',
      TargetPlatform.fuchsia => 'Fuchsia',
    };
  }

  Future<Uint8List?> _compress(XFile file) async {
    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    final maxDim = decoded.width > decoded.height
        ? decoded.width
        : decoded.height;
    const maxSize = 1600;
    final target = maxDim > maxSize ? maxSize : maxDim;
    final resized = img.copyResize(
      decoded,
      width: decoded.width >= decoded.height ? target : null,
      height: decoded.height > decoded.width ? target : null,
    );
    return Uint8List.fromList(img.encodeJpg(resized, quality: 85));
  }

  Future<void> _pickScreenshot() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2400,
      maxHeight: 2400,
      imageQuality: 90,
    );
    if (file == null) return;
    try {
      final bytes = await _compress(file);
      if (bytes == null) {
        if (mounted) {
          setState(() => _error = 'Não foi possível ler a imagem.');
        }
        return;
      }
      if (mounted) {
        setState(() {
          _screenshot = bytes;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Não foi possível processar a imagem.');
      }
    }
  }

  String? _validate() {
    final title = _title.text.trim();
    if (title.length < 5) {
      return 'Dê um título com pelo menos 5 caracteres.';
    }
    if (title.length > 120) {
      return 'O título deve ter no máximo 120 caracteres.';
    }
    final description = _description.text.trim();
    if (description.length < 10) {
      return 'Descreva o que aconteceu com pelo menos 10 caracteres.';
    }
    if (description.length > 4000) {
      return 'A descrição deve ter no máximo 4000 caracteres.';
    }
    return null;
  }

  Future<void> _submit() async {
    final problem = _validate();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final appVersion = await ref.read(appVersionProvider.future);
      final entry = await ref
          .read(feedbackRepositoryProvider)
          .submitBug(
            title: _title.text,
            description: _description.text,
            steps: _steps.text,
            expected: _expected.text,
            actual: _actual.text,
            platform: _platform,
            appVersion: appVersion,
            screenshotBytes: _screenshot,
          );
      ref.invalidate(myFeedbackProvider);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Relato recebido'),
          content: Text(
            'Recebemos seu relato. Protocolo ${entry.protocol}.\n\n'
            'Você pode acompanhar o status em Feedback > Meus envios.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (mounted) context.pop();
    } catch (error) {
      if (mounted) {
        setState(() => _error = friendlyFeedbackError(error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Reportar problema')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(
              'Conte o que aconteceu. Se puder, anexe um print da tela. '
              'Não envie dados sensíveis.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _title,
              maxLength: 120,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Título',
                hintText: 'Ex.: Feed não carrega ao abrir o app',
              ),
            ),
            TextField(
              controller: _description,
              minLines: 3,
              maxLines: 8,
              maxLength: 4000,
              decoration: const InputDecoration(
                labelText: 'O que aconteceu?',
                hintText: 'Descreva o problema e o que você estava fazendo.',
                counterText: '',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: AppSpacing.sm),
              title: const Text('Detalhes opcionais'),
              children: [
                TextField(
                  controller: _steps,
                  minLines: 2,
                  maxLines: 5,
                  maxLength: 2000,
                  decoration: const InputDecoration(
                    labelText: 'Passos para reproduzir',
                    hintText: '1. Abri o app\n2. Toquei em Feed',
                    counterText: '',
                  ),
                ),
                TextField(
                  controller: _expected,
                  minLines: 1,
                  maxLines: 3,
                  maxLength: 2000,
                  decoration: const InputDecoration(
                    labelText: 'O que você esperava?',
                    counterText: '',
                  ),
                ),
                TextField(
                  controller: _actual,
                  minLines: 1,
                  maxLines: 3,
                  maxLength: 2000,
                  decoration: const InputDecoration(
                    labelText: 'O que aconteceu de fato?',
                    counterText: '',
                  ),
                ),
                TextField(
                  controller: _device,
                  maxLength: 40,
                  decoration: const InputDecoration(
                    labelText: 'Aparelho e sistema (opcional)',
                    hintText: 'Ex.: Galaxy S23, Android 14',
                    counterText: '',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_screenshot != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Image.memory(
                  _screenshot!,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _busy
                      ? null
                      : () => setState(() => _screenshot = null),
                  icon: const Icon(Icons.close),
                  label: const Text('Remover print'),
                ),
              ),
            ],
            OutlinedButton.icon(
              onPressed: _busy ? null : _pickScreenshot,
              icon: const Icon(Icons.image_outlined),
              label: Text(
                _screenshot == null
                    ? 'Anexar print (opcional)'
                    : 'Trocar print',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(_error!, style: const TextStyle(color: AppColors.danger)),
            ],
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Enviar relato'),
            ),
          ],
        ),
      ),
    );
  }
}
