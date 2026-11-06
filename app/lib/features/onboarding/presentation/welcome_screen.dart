import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

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
              Text('Conexa', style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Conexoes reais,\ncom mais cuidado.',
                style: theme.textTheme.displayLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'A comunidade dos estudantes da UFV. Estude, conecte-se e '
                'acompanhe a vida do campus.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppColors.muted,
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => context.go('/sign-up'),
                child: const Text('Tenho 18 anos ou mais'),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Exclusivo para estudantes da UFV, maiores de 18 anos.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
