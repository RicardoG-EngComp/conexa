import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../verification/application/verification_providers.dart';

class IncompleteProfileBanner extends ConsumerWidget {
  const IncompleteProfileBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    return profileAsync.maybeWhen(
      data: (profile) {
        final missing = <String>[];
        if ((profile?['display_name'] as String?)?.trim().isEmpty ?? true) {
          missing.add('Nome');
        }
        if ((profile?['course'] as String?)?.trim().isEmpty ?? true) {
          missing.add('Curso');
        }
        if ((profile?['campus'] as String?)?.trim().isEmpty ?? true) {
          missing.add('Campus');
        }
        if ((profile?['avatar_url'] as String?)?.trim().isEmpty ?? true) {
          missing.add('Foto de perfil');
        }
        if (missing.isEmpty) return const SizedBox.shrink();

        final theme = Theme.of(context);
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
              Text(
                'Seu perfil está incompleto',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(
                'Você pode navegar, curtir e responder, mas não pode publicar '
                'nem enviar pedidos, e não aparece na descoberta. '
                'Complete: ${missing.join(', ')}.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.muted,
                ),
              ),
              TextButton(
                onPressed: () => context.push('/profile-setup'),
                child: const Text('Completar perfil'),
              ),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}
