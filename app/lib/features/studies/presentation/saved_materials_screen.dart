import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/study_providers.dart';

class SavedMaterialsScreen extends ConsumerWidget {
  const SavedMaterialsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(savedMaterialsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Materiais salvos')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Erro ao carregar salvos.')),
        data: (materials) {
          if (materials.isEmpty) {
            return Center(
              child: Text(
                'Nenhum material salvo.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.muted,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: materials.length,
            separatorBuilder: (_, _) => const Divider(),
            itemBuilder: (context, index) {
              final material = materials[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: AppColors.teal,
                  child: Icon(
                    material.kind == 'pdf'
                        ? Icons.picture_as_pdf_outlined
                        : material.kind == 'image'
                        ? Icons.image_outlined
                        : Icons.link,
                    color: AppColors.onPrimary,
                  ),
                ),
                title: Text(material.title),
                subtitle: Text(
                  '${material.authorName ?? 'Aluno'} · '
                  '${material.upvotes} uteis',
                ),
                onTap: () => context.push('/studies/material/${material.id}'),
              );
            },
          );
        },
      ),
    );
  }
}
