import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/errors/moderation_errors.dart';
import '../../../core/errors/moderation_ui.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../reports/presentation/report_dialog.dart';
import '../application/study_providers.dart';
import '../data/study_models.dart';

class StudyMaterialDetailScreen extends ConsumerWidget {
  const StudyMaterialDetailScreen({super.key, required this.materialId});

  final String materialId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final materialAsync = ref.watch(materialProvider(materialId));

    return Scaffold(
      appBar: AppBar(title: const Text('Material')),
      body: SafeArea(
        child: materialAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) =>
              const Center(child: Text('Erro ao carregar o material.')),
          data: (material) {
            if (material == null) {
              return const Center(
                child: Text('Material indisponível ou aguardando aprovação.'),
              );
            }
            return _MaterialContent(material: material);
          },
        ),
      ),
    );
  }
}

class _MaterialContent extends ConsumerWidget {
  const _MaterialContent({required this.material});

  final StudyMaterial material;

  Future<void> _openUrl(BuildContext context, String? url) async {
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Arquivo indisponível.')));
      return;
    }
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o arquivo.')),
      );
    }
  }

  Future<void> _review(
    BuildContext context,
    WidgetRef ref,
    int initialRating,
  ) async {
    final comment = TextEditingController();
    var stars = initialRating == 0 ? 5 : initialRating;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Avaliar material'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 1; i <= 5; i++)
                    IconButton(
                      onPressed: () => setDialogState(() => stars = i),
                      icon: Icon(
                        i <= stars ? Icons.star : Icons.star_border,
                        color: AppColors.teal,
                      ),
                    ),
                ],
              ),
              TextField(
                controller: comment,
                minLines: 2,
                maxLines: 4,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'Comentario (opcional)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Enviar'),
            ),
          ],
        ),
      ),
    );
    final text = comment.text.trim();
    comment.dispose();
    if (saved != true) return;

    try {
      await ref
          .read(studyRepositoryProvider)
          .rateMaterial(
            material.id,
            stars,
            comment: text.isEmpty ? null : text,
          );
      ref.invalidate(materialRatingProvider(material.id));
      ref.invalidate(materialReviewsProvider(material.id));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nao foi possivel avaliar.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final urlAsync = ref.watch(studyFileUrlProvider(material.id));
    final savedAsync = ref.watch(materialSavedProvider(material.id));
    final ratingAsync = ref.watch(materialRatingProvider(material.id));
    final reviewsAsync = ref.watch(materialReviewsProvider(material.id));
    final isImage = material.kind == 'image';
    final saved = savedAsync.asData?.value ?? false;
    final rating = ratingAsync.asData?.value;
    final myRating = (rating?['my_rating'] as num?)?.toInt() ?? 0;
    final average = (rating?['average'] as num?)?.toDouble() ?? 0;
    final ratingCount = (rating?['count'] as num?)?.toInt() ?? 0;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(material.title, style: theme.textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '${material.authorName ?? 'Aluno'} · ${_kindLabel(material.kind)}',
          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
        ),
        if (material.status != 'approved') ...[
          const SizedBox(height: AppSpacing.sm),
          Chip(
            label: Text(
              material.status == 'pending'
                  ? 'Aguardando aprovação'
                  : material.status == 'rejected'
                  ? 'Rejeitado'
                  : 'Oculto',
            ),
          ),
        ],
        if (material.description != null &&
            material.description!.trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(material.description!, style: theme.textTheme.bodyLarge),
        ],
        const SizedBox(height: AppSpacing.lg),
        if (isImage)
          urlAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => const Text('Não foi possível carregar a imagem.'),
            data: (url) => url == null
                ? const Text('Imagem indisponível.')
                : ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: CachedNetworkImage(
                      imageUrl: url,
                      cacheKey: material.storagePath ?? url,
                      fit: BoxFit.contain,
                      memCacheWidth:
                          (MediaQuery.sizeOf(context).width *
                                  MediaQuery.devicePixelRatioOf(context))
                              .round(),
                      placeholder: (_, _) => const SizedBox(
                        height: 180,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (_, _, _) =>
                          const Text('Não foi possível carregar a imagem.'),
                    ),
                  ),
          )
        else
          urlAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => const Text('Arquivo indisponível.'),
            data: (url) => FilledButton.icon(
              onPressed: () => _openUrl(context, url),
              icon: Icon(
                material.kind == 'pdf'
                    ? Icons.picture_as_pdf_outlined
                    : Icons.open_in_new,
              ),
              label: Text(material.kind == 'pdf' ? 'Abrir PDF' : 'Abrir link'),
            ),
          ),
        const SizedBox(height: AppSpacing.xl),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () async {
                try {
                  await ref
                      .read(studyRepositoryProvider)
                      .toggleVote(
                        materialId: material.id,
                        voted: material.votedByMe,
                      );
                  ref.invalidate(materialProvider(material.id));
                  ref.invalidate(materialsProvider(material.disciplineId));
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
                              fallback: 'Não foi possível votar.',
                            ),
                          ),
                        ),
                      );
                    }
                  }
                }
              },
              icon: Icon(
                material.votedByMe ? Icons.thumb_up : Icons.thumb_up_outlined,
              ),
              label: Text('${material.upvotes} úteis'),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (material.isApproved)
              TextButton.icon(
                onPressed: () => showReportDialog(
                  context,
                  ref,
                  reportedUserId: material.authorId,
                  targetType: 'material',
                  targetId: material.id,
                  contentSnapshot: material.title,
                ),
                icon: const Icon(Icons.flag_outlined),
                label: const Text('Denunciar'),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () async {
                try {
                  await ref
                      .read(studyRepositoryProvider)
                      .toggleMaterialSave(material.id, saved);
                  ref.invalidate(materialSavedProvider(material.id));
                  ref.invalidate(savedMaterialsProvider);
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Nao foi possivel salvar o material.'),
                      ),
                    );
                  }
                }
              },
              icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border),
              label: Text(saved ? 'Salvo' : 'Salvar'),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (ratingCount > 0)
              Text(
                '${average.toStringAsFixed(1)} · $ratingCount avaliacoes',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.muted,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            for (var i = 1; i <= 5; i++)
              IconButton(
                tooltip: '$i estrela(s)',
                onPressed: () async {
                  try {
                    await ref
                        .read(studyRepositoryProvider)
                        .rateMaterial(material.id, i);
                    ref.invalidate(materialRatingProvider(material.id));
                    ref.invalidate(materialReviewsProvider(material.id));
                  } catch (_) {}
                },
                icon: Icon(
                  i <= myRating ? Icons.star : Icons.star_border,
                  color: AppColors.teal,
                  size: 20,
                ),
              ),
            const SizedBox(width: AppSpacing.sm),
            TextButton(
              onPressed: () => _review(context, ref, myRating),
              child: const Text('Avaliar com comentario'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        reviewsAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (reviews) {
            if (reviews.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Avaliacoes', style: theme.textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xs),
                for (final review in reviews.take(10))
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${review.displayName} · ${review.rating} estrela(s)',
                            style: theme.textTheme.labelMedium,
                          ),
                          const SizedBox(height: 2),
                          Text(review.comment),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  String _kindLabel(String kind) {
    switch (kind) {
      case 'pdf':
        return 'PDF';
      case 'image':
        return 'Imagem';
      default:
        return 'Link';
    }
  }
}
