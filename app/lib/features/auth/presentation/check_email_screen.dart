import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

class CheckEmailScreen extends StatelessWidget {
  const CheckEmailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Confirme seu e-mail')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.mark_email_read_outlined, size: 48),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Enviamos um link de confirmacao.',
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Abra o e-mail e clique no link para ativar sua conta. '
                'Depois volte e entre.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppColors.muted,
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => context.go('/sign-in'),
                child: const Text('Ja confirmei, entrar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
