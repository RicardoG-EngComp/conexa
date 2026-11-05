import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/study_providers.dart';
import '../data/study_models.dart';

class StudyDisciplineScreen extends ConsumerWidget {
  const StudyDisciplineScreen({super.key, required this.disciplineId});

  final String disciplineId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final disciplinesAsync = ref.watch(disciplinesProvider);
    final materialsAsync = ref.watch(materialsProvider(disciplineId));
    final canUpload = ref.watch(canUploadProvider).asData?.value ?? false;

    final discipline = disciplinesAsync.asData?.value
        .where((d) => d.id == disciplineId)
        .firstOrNull;

    return Scaffold(
      appBar: AppBar(title: Text(discipline?.name ?? 'Disciplina')),
      floatingActionButton: canUpload
          ? FloatingActionButton.extended(
              onPressed: () async {
                await context.push(
                  '/studies/upload?discipline=$disciplineId',
                );
                ref.invalidate(materialsProvider(disciplineId));
              },
              icon: const Icon(Icons.upload_file),
              label: const Text('Enviar'),
            )
          : null,
      body: SafeArea(
        child: materialsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) =>
              const Center(child: Text('Erro ao carregar os materiais.')),
          data: (materials) {
            if (materials.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text(
                    'Nenhum material aprovado ainda. '
                    'Os envios passam por aprovação.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(materialsProvider(disciplineId));
                await ref.read(materialsProvider(disciplineId).future);
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: materials.length,
                itemBuilder: (context, index) {
                  final material = materials[index];
                  return _MaterialCard(material: material);
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MaterialCard extends StatelessWidget {
  const _MaterialCard({required this.material});

  final StudyMaterial material;

  IconData get _icon {
    switch (material.kind) {
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'image':
        return Icons.image_outlined;
      default:
        return Icons.link;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = material.status;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.teal,
          child: Icon(_icon, color: Colors.white),
        ),
        title: Text(material.title, style: theme.textTheme.titleSmall),
        subtitle: Text(
          '${material.authorName ?? 'Aluno'} · ${material.upvotes} úteis',
        ),
        trailing: status == 'approved'
            ? null
            : Chip(
                label: Text(
                  status == 'pending'
                      ? 'Pendente'
                      : status == 'rejected'
                          ? 'Rejeitado'
                          : 'Oculto',
                  style: theme.textTheme.bodySmall,
                ),
              ),
        onTap: () => context.push('/studies/material/${material.id}'),
      ),
    );
  }
}
