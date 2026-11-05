import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/errors/moderation_errors.dart';
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Arquivo indisponível.')),
      );
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final urlAsync = ref.watch(studyFileUrlProvider(material.id));
    final isImage = material.kind == 'image';

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
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) =>
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
              label: Text(
                material.kind == 'pdf' ? 'Abrir PDF' : 'Abrir link',
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.xl),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () async {
                try {
                  await ref.read(studyRepositoryProvider).toggleVote(
                        materialId: material.id,
                        voted: material.votedByMe,
                      );
                  ref.invalidate(materialProvider(material.id));
                  ref.invalidate(materialsProvider(material.disciplineId));
                } catch (error) {
                  if (context.mounted) {
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
