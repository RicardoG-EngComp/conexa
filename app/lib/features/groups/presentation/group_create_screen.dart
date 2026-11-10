import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/moderation_errors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../profile/data/ufv_courses.dart';
import '../application/group_providers.dart';
import 'group_common.dart';

class GroupCreateScreen extends ConsumerStatefulWidget {
  const GroupCreateScreen({super.key});

  @override
  ConsumerState<GroupCreateScreen> createState() => _GroupCreateScreenState();
}

class _GroupCreateScreenState extends ConsumerState<GroupCreateScreen> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  String _category = defaultGroupCategory;
  String _campus = ufvCampuses.first;
  String? _course;
  String _visibility = 'private';
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escolha um nome para o grupo.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final id = await ref.read(groupRepositoryProvider).createGroup(
        name: name,
        description: _description.text.trim().isEmpty
            ? null
            : _description.text.trim(),
        category: _category,
        campus: _campus,
        course: _course,
        visibility: _visibility,
      );
      ref.invalidate(myGroupsProvider);
      if (mounted) {
        context.go('/groups');
        context.push('/groups/$id');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              friendlyModerationError(
                error,
                fallback: 'Nao foi possivel criar o grupo.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Criar grupo')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          TextField(
            controller: _name,
            maxLength: 80,
            decoration: const InputDecoration(labelText: 'Nome do grupo'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _description,
            minLines: 2,
            maxLines: 4,
            maxLength: 1000,
            decoration: const InputDecoration(
              labelText: 'Descrição (opcional)',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String>(
            initialValue: _category,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Categoria'),
            items: groupCategories
                .map((c) => DropdownMenuItem<String>(value: c, child: Text(c)))
                .toList(),
            onChanged: (value) => setState(() => _category = value!),
          ),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String>(
            initialValue: _campus,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Campus'),
            items: ufvCampuses
                .map((c) => DropdownMenuItem<String>(value: c, child: Text(c)))
                .toList(),
            onChanged: (value) => setState(() => _campus = value!),
          ),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String?>(
            initialValue: _course,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Curso (opcional)'),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('Nenhum curso')),
              ...ufvCourses.map(
                (c) => DropdownMenuItem<String?>(
                  value: c,
                  child: Text(c, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
            onChanged: (value) => setState(() => _course = value),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Visibilidade', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'private',
                label: Text('Privado'),
                icon: Icon(Icons.lock_outline, size: 16),
              ),
              ButtonSegment(
                value: 'public',
                label: Text('Público'),
                icon: Icon(Icons.public, size: 16),
              ),
            ],
            selected: {_visibility},
            onSelectionChanged: (values) =>
                setState(() => _visibility = values.first),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _visibility == 'public'
                ? 'Grupos públicos passam por aprovação da moderação e recebem '
                    'o selo oficial.'
                : 'Grupos privados só aparecem para quem tem convite.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Criar grupo'),
          ),
        ],
      ),
    );
  }
}
