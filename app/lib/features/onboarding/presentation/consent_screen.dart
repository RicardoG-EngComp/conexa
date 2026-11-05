import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/legal_urls.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/data/auth_repository.dart';

class ConsentScreen extends ConsumerStatefulWidget {
  const ConsentScreen({super.key});

  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends ConsumerState<ConsentScreen> {
  bool _terms = false;
  bool _privacy = false;
  bool _guidelines = false;
  bool _loading = false;
  String? _error;

  bool get _canContinue => _terms && _privacy && _guidelines;

  Future<void> _openLegal(String url) async {
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      setState(() => _error = 'Nao foi possivel abrir o link.');
    }
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ref
          .read(authRepositoryProvider)
          .saveConsents(AuthRepository.requiredConsents);
      final complete = await ref
          .read(authRepositoryProvider)
          .isProfileComplete();
      if (!mounted) return;
      context.go(complete ? '/feed' : '/profile-setup');
    } catch (_) {
      setState(() => _error = 'Nao foi possivel salvar. Tente novamente.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Privacidade e consentimento')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(
              'Precisamos do seu consentimento para seguir.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            CheckboxListTile(
              value: _terms,
              onChanged: (v) => setState(() => _terms = v ?? false),
              title: const Text('Aceito os Termos de Uso'),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            CheckboxListTile(
              value: _privacy,
              onChanged: (v) => setState(() => _privacy = v ?? false),
              title: const Text('Aceito a Politica de Privacidade'),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            CheckboxListTile(
              value: _guidelines,
              onChanged: (v) => setState(() => _guidelines = v ?? false),
              title: const Text('Aceito as Diretrizes da Comunidade'),
              subtitle: const Text(
                'Proibido intolerancia, discriminacao, violencia e '
                'conteudo explicito pornografico.',
              ),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.md,
              children: [
                TextButton(
                  onPressed: () => _openLegal(LegalUrls.terms),
                  child: const Text('Ler Termos'),
                ),
                TextButton(
                  onPressed: () => _openLegal(LegalUrls.privacy),
                  child: const Text('Ler Privacidade'),
                ),
                TextButton(
                  onPressed: () => _openLegal(LegalUrls.guidelines),
                  child: const Text('Ler Diretrizes'),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                _error!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.danger,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: (_canContinue && !_loading) ? _submit : null,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Aceitar e continuar'),
            ),
          ],
        ),
      ),
    );
  }
}
