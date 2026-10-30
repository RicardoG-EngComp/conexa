import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';

class ProfileSetupScreen extends StatelessWidget {
  const ProfileSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Seu perfil')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text('Monte seu perfil', style: theme.textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.md),
            const Text('Fotos, prompts e interesses. Voce pode editar depois.'),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: () => context.go('/preferences'),
              child: const Text('Continuar'),
            ),
          ],
        ),
      ),
    );
  }
}
