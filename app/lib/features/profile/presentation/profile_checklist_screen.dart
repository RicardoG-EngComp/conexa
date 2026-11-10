import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../verification/application/verification_providers.dart';
import '../application/profile_providers.dart';

class ProfileChecklistScreen extends ConsumerWidget {
  const ProfileChecklistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Checklist do perfil')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            const Center(child: Text('Erro ao carregar o perfil.')),
        data: (profile) {
          final userId = profile?['id'] as String?;
          final favoritesAsync = userId == null
              ? null
              : ref.watch(favoriteIdsProvider(userId));
          final hasFavorites =
              favoritesAsync?.asData?.value.isNotEmpty ?? false;

          final required = <_ChecklistItem>[
            _ChecklistItem(
              label: 'Nome',
              done:
                  !((profile?['display_name'] as String?)?.trim().isEmpty ??
                      true),
            ),
            _ChecklistItem(
              label: 'Curso',
              done: !((profile?['course'] as String?)?.trim().isEmpty ?? true),
            ),
            _ChecklistItem(
              label: 'Campus',
              done: !((profile?['campus'] as String?)?.trim().isEmpty ?? true),
            ),
            _ChecklistItem(
              label: 'Foto de perfil',
              done:
                  !((profile?['avatar_url'] as String?)?.trim().isEmpty ??
                      true),
            ),
          ];

          final optional = <_ChecklistItem>[
            _ChecklistItem(
              label: 'Bio',
              done: ((profile?['bio'] as String?)?.trim().length ?? 0) >= 10,
            ),
            _ChecklistItem(
              label: 'Prompts',
              done: ((profile?['prompts'] as List?) ?? const []).isNotEmpty,
            ),
            _ChecklistItem(
              label: 'Fotos extras',
              done: ((profile?['photos'] as List?) ?? const []).isNotEmpty,
            ),
            _ChecklistItem(label: 'Interesses', done: hasFavorites),
          ];

          final requiredDone = required.where((item) => item.done).length;
          final optionalDone = optional.where((item) => item.done).length;

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text('Essenciais', style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '$requiredDone de ${required.length} completos. '
                'Sem eles, seu perfil nao aparece na descoberta e algumas '
                'acoes ficam limitadas.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              ...required.map((item) => _ChecklistTile(item: item)),
              const Divider(height: AppSpacing.xl),
              Text('Opcionais', style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '$optionalDone de ${optional.length} completos. '
                'Ajudam a gerar conexoes melhores, mas nao bloqueiam o uso.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              ...optional.map((item) => _ChecklistTile(item: item)),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: () => context.push('/profile-setup'),
                child: const Text('Completar perfil'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ChecklistItem {
  const _ChecklistItem({required this.label, required this.done});

  final String label;
  final bool done;
}

class _ChecklistTile extends StatelessWidget {
  const _ChecklistTile({required this.item});

  final _ChecklistItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        item.done ? Icons.check_circle : Icons.radio_button_unchecked,
        color: item.done ? AppColors.teal : AppColors.muted,
      ),
      title: Text(item.label, style: theme.textTheme.bodyLarge),
      subtitle: item.done
          ? null
          : Text(
              'Pendente',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.muted,
              ),
            ),
    );
  }
}
