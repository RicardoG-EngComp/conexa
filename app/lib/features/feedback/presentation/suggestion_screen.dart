import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/feedback_providers.dart';
import '../data/feedback_errors.dart';

class SuggestionScreen extends ConsumerStatefulWidget {
  const SuggestionScreen({super.key});

  @override
  ConsumerState<SuggestionScreen> createState() => _SuggestionScreenState();
}

class _SuggestionScreenState extends ConsumerState<SuggestionScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _problem = TextEditingController();
  final _proposal = TextEditingController();
  final _impact = TextEditingController();

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _problem.dispose();
    _proposal.dispose();
    _impact.dispose();
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
      return 'Descreva a sugestão com pelo menos 10 caracteres.';
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
          .submitSuggestion(
            title: _title.text,
            description: _description.text,
            problem: _problem.text,
            proposal: _proposal.text,
            impact: _impact.text,
            platform: _platform,
            appVersion: appVersion,
          );
      ref.invalidate(myFeedbackProvider);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Sugestão recebida'),
          content: Text(
            'Recebemos sua sugestão. Protocolo ${entry.protocol}.\n\n'
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
      appBar: AppBar(title: const Text('Enviar sugestão')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(
              'Pensou em uma função ou melhoria? Conte para a equipe. '
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
                hintText: 'Ex.: Filtro de materiais por período',
              ),
            ),
            TextField(
              controller: _description,
              minLines: 3,
              maxLines: 8,
              maxLength: 4000,
              decoration: const InputDecoration(
                labelText: 'Descreva a sugestão',
                hintText: 'O que você gostaria que existisse ou mudasse?',
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
                  controller: _problem,
                  minLines: 2,
                  maxLines: 5,
                  maxLength: 2000,
                  decoration: const InputDecoration(
                    labelText: 'Qual problema isso resolve?',
                    counterText: '',
                  ),
                ),
                TextField(
                  controller: _proposal,
                  minLines: 2,
                  maxLines: 5,
                  maxLength: 2000,
                  decoration: const InputDecoration(
                    labelText: 'Como você imagina que funcionaria?',
                    counterText: '',
                  ),
                ),
                TextField(
                  controller: _impact,
                  minLines: 1,
                  maxLines: 3,
                  maxLength: 1000,
                  decoration: const InputDecoration(
                    labelText: 'Quem seria beneficiado? (opcional)',
                    counterText: '',
                  ),
                ),
              ],
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
                  : const Text('Enviar sugestão'),
            ),
          ],
        ),
      ),
    );
  }
}
