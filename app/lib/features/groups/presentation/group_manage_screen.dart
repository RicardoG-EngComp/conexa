import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/moderation_errors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../profile/data/ufv_courses.dart';
import '../application/group_providers.dart';
import 'group_common.dart';

class GroupManageScreen extends ConsumerStatefulWidget {
  const GroupManageScreen({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<GroupManageScreen> createState() => _GroupManageScreenState();
}

class _GroupManageScreenState extends ConsumerState<GroupManageScreen> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  String _category = defaultGroupCategory;
  String _campus = ufvCampuses.first;
  String? _course;
  bool _saving = false;
  bool _initialized = false;

  void _init(dynamic detail) {
    if (_initialized || detail == null) return;
    _name.text = detail.name;
    _description.text = detail.description ?? '';
    _category = normalizeGroupCategory(detail.category);
    _campus = detail.campus;
    _course = detail.course;
    _initialized = true;
  }

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
      await ref.read(groupRepositoryProvider).updateGroup(
        widget.groupId,
        name: name,
        description: _description.text.trim().isEmpty
            ? null
            : _description.text.trim(),
        category: _category,
        campus: _campus,
        course: _course,
      );
      ref.invalidate(groupDetailProvider(widget.groupId));
      ref.invalidate(myGroupsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Grupo atualizado.')),
        );
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              friendlyModerationError(
                error,
                fallback: 'Nao foi possivel atualizar o grupo.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _requestPublic() async {
    try {
      await ref.read(groupRepositoryProvider).requestPublicGroup(widget.groupId);
      ref.invalidate(groupDetailProvider(widget.groupId));
      ref.invalidate(myGroupsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pedido de selo oficial enviado para a moderacao.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              friendlyModerationError(
                error,
                fallback: 'Nao foi possivel solicitar o selo.',
              ),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detailAsync = ref.watch(groupDetailProvider(widget.groupId));
    final detail = detailAsync.asData?.value;
    _init(detail);

    return Scaffold(
      appBar: AppBar(title: const Text('Gerenciar grupo')),
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
            decoration: const InputDecoration(labelText: 'Descrição (opcional)'),
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
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Salvar alterações'),
          ),
          if (detail != null && detail.visibility == 'private') ...[
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: _requestPublic,
              icon: const Icon(Icons.verified_outlined),
              label: const Text('Pedir selo oficial (tornar público)'),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Grupos públicos passam por aprovação da moderação.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
