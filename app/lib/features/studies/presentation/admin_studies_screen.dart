import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/study_providers.dart';
import '../data/study_models.dart';

class AdminStudiesScreen extends ConsumerWidget {
  const AdminStudiesScreen({super.key});

  Future<void> _invite(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Convidar uploader'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email do aluno',
            hintText: 'aluno@alunos.ufv.br',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Convidar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (email == null || email.isEmpty) return;

    try {
      await ref.read(studyRepositoryProvider).grantUploader(email);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Uploader liberado.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível convidar. Verifique o email.'),
          ),
        );
      }
    }
  }

  Future<void> _review(
    BuildContext context,
    WidgetRef ref,
    StudyMaterial material,
    bool approve,
  ) async {
    try {
      await ref.read(studyRepositoryProvider).reviewMaterial(
            materialId: material.id,
            approve: approve,
          );
      ref.invalidate(pendingMaterialsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              approve ? 'Material aprovado.' : 'Material rejeitado.',
            ),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível revisar o material.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final pendingAsync = ref.watch(pendingMaterialsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Materiais pendentes'),
        actions: [
          IconButton(
            tooltip: 'Convidar uploader',
            icon: const Icon(Icons.person_add_alt_1_outlined),
            onPressed: () => _invite(context, ref),
          ),
        ],
      ),
      body: SafeArea(
        child: pendingAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) =>
              const Center(child: Text('Erro ao carregar materiais.')),
          data: (materials) {
            if (materials.isEmpty) {
              return Center(
                child: Text(
                  'Nenhum material pendente.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: materials.length,
              itemBuilder: (context, index) {
                final material = materials[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          material.title,
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${material.authorName ?? 'Aluno'} · '
                          '${material.kind.toUpperCase()} · '
                          '${material.createdAt.toLocal().toString().split(' ').first}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                        if (material.description != null &&
                            material.description!.trim().isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Text(material.description!),
                        ],
                        const SizedBox(height: AppSpacing.md),
                        Wrap(
                          spacing: AppSpacing.sm,
                          children: [
                            OutlinedButton(
                              onPressed: () => _review(
                                context,
                                ref,
                                material,
                                false,
                              ),
                              child: const Text('Rejeitar'),
                            ),
                            FilledButton(
                              onPressed: () => _review(
                                context,
                                ref,
                                material,
                                true,
                              ),
                              child: const Text('Aprovar'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
