import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/badge_providers.dart';

class AdminBadgesScreen extends ConsumerStatefulWidget {
  const AdminBadgesScreen({super.key});

  @override
  ConsumerState<AdminBadgesScreen> createState() => _AdminBadgesScreenState();
}

class _AdminBadgesScreenState extends ConsumerState<AdminBadgesScreen> {
  static const _slug = 'testador-oficial-beta-2026';
  final _emails = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _emails.dispose();
    super.dispose();
  }

  Future<void> _grant() async {
    final emails = _emails.text
        .split(RegExp(r'[\n,;]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    if (emails.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cole pelo menos um email UFV.')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final count = await ref
          .read(badgeRepositoryProvider)
          .grantBadges(emails: emails, slug: _slug);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Insignia concedida a $count conta(s).'),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nao foi possivel conceder a insignia.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Insignias')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(
              'Testador Oficial - Beta 2026',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Cole os emails institucionais UFV dos testadores que '
              'concluiram as 4 semanas e responderam ao feedback. '
              'Um email por linha ou separados por virgula.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _emails,
              minLines: 6,
              maxLines: 12,
              decoration: const InputDecoration(
                labelText: 'Emails UFV',
                hintText: 'aluno1@alunos.ufv.br\naluno2@alunos.ufv.br',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: _busy ? null : _grant,
              icon: const Icon(Icons.military_tech_outlined),
              label: _busy
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Conceder insignia'),
            ),
          ],
        ),
      ),
    );
  }
}
