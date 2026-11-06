import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../verification/application/verification_providers.dart';
import '../application/profile_providers.dart';

class IncompleteProfileBanner extends ConsumerWidget {
  const IncompleteProfileBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);

    return profileAsync.maybeWhen(
      data: (profile) {
        final userId = profile?['id'] as String?;
        final favoritesAsync = userId == null
            ? null
            : ref.watch(favoriteIdsProvider(userId));
        final hasFavorites =
            favoritesAsync?.asData?.value.isNotEmpty ?? false;

        final coreMissing = <String>[];
        if ((profile?['display_name'] as String?)?.trim().isEmpty ?? true) {
          coreMissing.add('Nome');
        }
        if ((profile?['course'] as String?)?.trim().isEmpty ?? true) {
          coreMissing.add('Curso');
        }
        if ((profile?['campus'] as String?)?.trim().isEmpty ?? true) {
          coreMissing.add('Campus');
        }
        if ((profile?['avatar_url'] as String?)?.trim().isEmpty ?? true) {
          coreMissing.add('Foto de perfil');
        }

        if (coreMissing.isNotEmpty) {
          return _Banner(
            title: 'Seu perfil está incompleto',
            message:
                'Você pode navegar, curtir e responder, mas não pode publicar '
                'nem enviar pedidos, e não aparece na descoberta. '
                'Complete: ${coreMissing.join(', ')}.',
            actionLabel: 'Completar perfil',
          );
        }

        final enrichmentMissing = <String>[];
        final bio = (profile?['bio'] as String?)?.trim() ?? '';
        if (bio.length < 10) {
          enrichmentMissing.add('Bio');
        }
        final prompts = (profile?['prompts'] as List?) ?? const [];
        if (prompts.isEmpty) {
          enrichmentMissing.add('Prompts');
        }
        final photos = (profile?['photos'] as List?) ?? const [];
        if (photos.isEmpty) {
          enrichmentMissing.add('Fotos');
        }
        if (!hasFavorites) {
          enrichmentMissing.add('Interesses');
        }

        if (enrichmentMissing.isEmpty) {
          return const SizedBox.shrink();
        }

        return _Banner(
          title: 'Complete seu perfil',
          message:
              'Seu perfil está básico. Adicionar bio, prompts, fotos e '
              'interesses melhora suas conexões reais. Falta: '
              '${enrichmentMissing.join(', ')}.',
          actionLabel: 'Completar perfil',
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.title,
    required this.message,
    required this.actionLabel,
  });

  final String title;
  final String message;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
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
          Text(title, style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.muted,
            ),
          ),
          TextButton(
            onPressed: () => context.push('/profile-setup'),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}
