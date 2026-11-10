import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/moderation_errors.dart';
import '../../../core/errors/moderation_ui.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../badges/application/badge_providers.dart';
import '../../badges/data/badge_models.dart';
import 'incomplete_profile_banner.dart';
import '../../blocks/application/block_providers.dart';
import '../../chat/application/chat_providers.dart';
import '../../connections/presentation/connection_actions.dart';
import '../../connections/presentation/profile_message_button.dart';
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
    final badgesAsync = ref.watch(userBadgesProvider(id));

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
          if (!isOwn)
            IconButton(
              tooltip: 'Bloquear',
              icon: const Icon(Icons.block),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Bloquear usuario?'),
                    content: const Text(
                      'O perfil desaparecera para voces dois e a pessoa nao podera enviar mensagens.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancelar'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Bloquear'),
                      ),
                    ],
                  ),
                );
                if (confirm != true) return;
                await ref.read(blockRepositoryProvider).block(id);
                if (context.mounted) context.pop();
              },
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
            final isPrivate = profile['profile_private'] == true;

            return ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                if (isOwn) const IncompleteProfileBanner(),
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
                    label: const Text('UFV'),
                  ),
                ),
                if ((badgesAsync.asData?.value ?? const <ProfileBadge>[])
                    .isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 6,
                    runSpacing: 6,
                    children: badgesAsync.asData!.value
                        .map((badge) => _BadgeChip(badge: badge))
                        .toList(),
                  ),
                ],
                if (!isOwn) ...[
                  const SizedBox(height: AppSpacing.md),
                  ConnectionActions(targetId: id),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      ProfileMessageButton(
                        targetId: id,
                        onRequestMessage: () => _sendRequest(context, ref, id),
                      ),
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
                if (isPrivate) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lock_outline),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Feed privado: os posts ficam visiveis apenas para conexoes.',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
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
                        if (byCategory.isEmpty) {
                          return const SizedBox.shrink();
                        }
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

  Future<void> _sendRequest(
    BuildContext context,
    WidgetRef ref,
    String targetId,
  ) async {
    final controller = TextEditingController();
    final message = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pedido de mensagem'),
        content: TextField(
          controller: controller,
          maxLength: 150,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Escreva uma breve apresentacao...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Enviar pedido'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (message == null || message.isEmpty) return;

    try {
      final result = await ref
          .read(chatRepositoryProvider)
          .sendMessageRequest(otherUserId: targetId, message: message);
      final status = result['status'] as String?;
      final convId = result['id'] as String?;
      if (!context.mounted) return;
      if (status == 'accepted' && convId != null) {
        context.push('/chats/$convId');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pedido enviado. Aguarde a aprovacao.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        if (needsGuidelinesAcceptance(error)) {
          await showGuidelinesConsentDialog(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                friendlyModerationError(
                  error,
                  fallback: 'Nao foi possivel enviar o pedido.',
                ),
              ),
            ),
          );
        }
      }
    }
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({required this.badge});

  final ProfileBadge badge;

  IconData get _icon {
    switch (badge.icon) {
      case 'science':
        return Icons.science_outlined;
      case 'verified':
        return Icons.verified_outlined;
      case 'school':
        return Icons.school_outlined;
      default:
        return Icons.military_tech_outlined;
    }
  }

  Color get _color {
    final cleaned = badge.color.replaceAll('#', '');
    final value = int.tryParse('FF$cleaned', radix: 16);
    return value == null ? AppColors.teal : Color(value);
  }

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(_icon, size: 16, color: _color),
      label: Text(badge.name),
      backgroundColor: _color.withValues(alpha: 0.12),
      side: BorderSide(color: _color.withValues(alpha: 0.35)),
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
