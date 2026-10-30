import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key});

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _terms = false;
  bool _privacy = false;
  bool _biometrics = false;

  bool get _canContinue => _terms && _privacy && _biometrics;

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
              value: _biometrics,
              onChanged: (v) => setState(() => _biometrics = v ?? false),
              title: const Text(
                'Autorizo o uso de biometria para verificar 18+',
              ),
              subtitle: const Text('Necessario para confirmar sua identidade.'),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: _canContinue
                  ? () => context.go('/verification')
                  : null,
              child: const Text('Aceitar e continuar'),
            ),
          ],
        ),
      ),
    );
  }
}
