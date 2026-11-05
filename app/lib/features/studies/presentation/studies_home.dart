import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/study_providers.dart';
import '../data/study_models.dart';

class StudiesHome extends ConsumerStatefulWidget {
  const StudiesHome({super.key});

  @override
  ConsumerState<StudiesHome> createState() => _StudiesHomeState();
}

class _StudiesHomeState extends ConsumerState<StudiesHome> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disciplinesAsync = ref.watch(disciplinesProvider);
    final canUploadAsync = ref.watch(canUploadProvider);

    return disciplinesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) =>
          const Center(child: Text('Erro ao carregar as disciplinas.')),
      data: (disciplines) {
        final query = _search.text.trim().toLowerCase();
        final filtered = disciplines.where((d) {
          if (query.isEmpty) return true;
          return d.name.toLowerCase().contains(query) ||
              (d.course ?? '').toLowerCase().contains(query);
        }).toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          children: [
            Text(
              'Material da disciplina certa, dúvidas e grupos de estudo.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _search,
              decoration: const InputDecoration(
                hintText: 'Buscar disciplina...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.md),
            canUploadAsync.maybeWhen(
              data: (canUpload) => canUpload
                  ? FilledButton.icon(
                      onPressed: () async {
                        await context.push('/studies/upload');
                        ref.invalidate(disciplinesProvider);
                      },
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Enviar material'),
                    )
                  : Text(
                      'Upload restrito aos convidados do piloto.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
              orElse: () => const SizedBox.shrink(),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Disciplinas', style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Text(
                  'Nenhuma disciplina encontrada.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
              )
            else
              ...filtered.map(
                (d) => _DisciplineCard(discipline: d),
              ),
          ],
        );
      },
    );
  }
}

class _DisciplineCard extends StatelessWidget {
  const _DisciplineCard({required this.discipline});

  final Discipline discipline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: AppColors.teal,
          child: Icon(Icons.menu_book_outlined, color: Colors.white),
        ),
        title: Text(discipline.name, style: theme.textTheme.titleSmall),
        subtitle: Text(
          [
            if (discipline.course != null) discipline.course!,
            discipline.campus,
          ].join(' · '),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/studies/discipline/${discipline.id}'),
      ),
    );
  }
}
