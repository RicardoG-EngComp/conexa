import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../chat/application/chat_providers.dart';
import '../../reports/presentation/report_dialog.dart';
import '../application/profile_providers.dart';
import '../data/ufv_courses.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key, this.userId});

  final String? userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final myId = Supabase.instance.client.auth.currentUser?.id;
    final id = userId ?? myId;
    if (id == null) {
      return const Scaffold(body: Center(child: Text('Perfil indisponível.')));
    }
    final isOwn = id == myId;
    final profileAsync = ref.watch(publicProfileProvider(id));
    final favoritesAsync = ref.watch(favoriteIdsProvider(id));
    final catalogAsync = ref.watch(catalogProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(isOwn ? 'Meu perfil' : 'Perfil'),
        actions: [
          if (isOwn)
            IconButton(
              tooltip: 'Editar perfil',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push('/profile-setup'),
            ),
        ],
      ),
      body: SafeArea(
        child: profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) =>
              const Center(child: Text('Erro ao carregar perfil.')),
          data: (profile) {
            if (profile == null) {
              return const Center(child: Text('Perfil não encontrado.'));
            }
            final photos = ((profile['photos'] as List?) ?? [])
                .map((e) => e as String)
                .toList();
            final prompts = (profile['prompts'] as List?) ?? [];
            final avatar = profile['avatar_url'] as String?;

            return ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Center(
                  child: ClipOval(
                    child: SizedBox(
                      width: 112,
                      height: 112,
                      child: avatar == null
                          ? Container(
                              color: AppColors.border,
                              child: const Icon(Icons.person, size: 56),
                            )
                          : _SignedImage(path: avatar, width: 112, height: 112),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Center(
                  child: Text(
                    (profile['display_name'] as String?) ?? 'Estudante UFV',
                    style: theme.textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Center(
                  child: Text(
                    [profile['course'], profile['campus']]
                        .where((e) => e != null && e.toString().isNotEmpty)
                        .join(' • '),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.muted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Center(
                  child: Chip(
                    avatar: const Icon(Icons.verified, size: 16),
                    label: const Text('Estudante UFV'),
                  ),
                ),
                if (!isOwn) ...[
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FilledButton.icon(
                        onPressed: () async {
                          final convId = await ref
                              .read(chatRepositoryProvider)
                              .startConversation(id);
                          if (context.mounted) {
                            context.push('/chats/$convId');
                          }
                        },
                        icon: const Icon(Icons.chat_bubble_outline, size: 18),
                        label: const Text('Mensagem'),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      OutlinedButton(
                        onPressed: () => showReportDialog(
                          context,
                          ref,
                          reportedUserId: id,
                          targetType: 'profile',
                          contentSnapshot: profile['bio'] as String?,
                        ),
                        child: const Text('Denunciar'),
                      ),
                    ],
                  ),
                ],
                if ((profile['bio'] as String?)?.isNotEmpty == true) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text('Sobre', style: theme.textTheme.titleSmall),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    profile['bio'] as String,
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
                if (prompts.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text('Prompts', style: theme.textTheme.titleSmall),
                  for (final p in prompts)
                    if (p is Map)
                      Container(
                        margin: const EdgeInsets.only(top: AppSpacing.sm),
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
                              (p['question'] as String?) ?? '',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.muted,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              (p['answer'] as String?) ?? '',
                              style: theme.textTheme.bodyLarge,
                            ),
                          ],
                        ),
                      ),
                ],
                if (photos.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text('Fotos', style: theme.textTheme.titleSmall),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: photos
                        .map(
                          (path) => ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            child: _SignedImage(
                              path: path,
                              width: 104,
                              height: 104,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                favoritesAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (favoriteIds) {
                    return catalogAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
                      data: (catalog) {
                        final names = {
                          for (final item in catalog)
                            item['id'] as String: item['name'] as String,
                        };
                        final categories = {
                          for (final item in catalog)
                            item['id'] as String: item['category'] as String,
                        };
                        final byCategory = <String, List<String>>{};
                        for (final favId in favoriteIds) {
                          final cat = categories[favId];
                          if (cat == null) continue;
                          byCategory.putIfAbsent(cat, () => []).add(favId);
                        }
                        if (byCategory.isEmpty) return const SizedBox.shrink();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Favoritos',
                              style: theme.textTheme.titleSmall,
                            ),
                            for (final entry in favoriteCategoryLabels.entries)
                              if (byCategory[entry.key]?.isNotEmpty == true)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: AppSpacing.sm,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        entry.value,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(color: AppColors.muted),
                                      ),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: byCategory[entry.key]!
                                            .map(
                                              (favId) => Chip(
                                                label: Text(names[favId] ?? ''),
                                              ),
                                            )
                                            .toList(),
                                      ),
                                    ],
                                  ),
                                ),
                          ],
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SignedImage extends ConsumerWidget {
  const _SignedImage({
    required this.path,
    required this.width,
    required this.height,
  });

  final String path;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = ref.watch(signedUrlProvider(path));
    return url.when(
      data: (value) {
        if (value == null) {
          return Container(
            width: width,
            height: height,
            color: AppColors.border,
            child: const Icon(Icons.image_not_supported_outlined, size: 18),
          );
        }
        return Image.network(
          value,
          width: width,
          height: height,
          fit: BoxFit.cover,
        );
      },
      loading: () => SizedBox(
        width: width,
        height: height,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, _) => Container(
        width: width,
        height: height,
        color: AppColors.border,
        child: const Icon(Icons.image_not_supported_outlined, size: 18),
      ),
    );
  }
}
