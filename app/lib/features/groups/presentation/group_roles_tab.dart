import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/group_providers.dart';
import '../data/group_models.dart';
import '../data/group_repository.dart';
import 'group_common.dart';

class GroupRolesTab extends ConsumerWidget {
  const GroupRolesTab({
    super.key,
    required this.groupId,
    required this.detail,
    required this.roles,
    required this.onChanged,
  });

  final String groupId;
  final GroupDetail detail;
  final List<GroupRole> roles;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final repo = ref.read(groupRepositoryProvider);

    Future<void> editRole({GroupRole? role}) async {
      final name = TextEditingController(text: role?.name ?? '');
      final selected = (role?.permissions ?? const <String>[]).toSet();
      final result = await showDialog<GroupRole>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text(role == null ? 'Criar cargo' : 'Editar cargo'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Nome do cargo'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  for (final permission in GroupRepository.allPermissions)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(permissionLabel(permission)),
                      value: selected.contains(permission),
                      onChanged: (value) => setState(() {
                        if (value ?? false) {
                          selected.add(permission);
                        } else {
                          selected.remove(permission);
                        }
                      }),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () {
                  final label = name.text.trim();
                  if (label.isEmpty) return;
                  Navigator.pop(
                    ctx,
                    GroupRole(
                      id: role?.id ?? '',
                      name: label,
                      permissions: selected.toList(),
                      isSystem: role?.isSystem ?? false,
                      memberCount: role?.memberCount ?? 0,
                    ),
                  );
                },
                child: const Text('Salvar cargo'),
              ),
            ],
          ),
        ),
      );
      name.dispose();
      if (result == null || !context.mounted) return;

      try {
        if (role == null) {
          await repo.createRole(groupId, result.name, result.permissions);
        } else {
          await repo.updateRole(role.id, result.name, result.permissions);
        }
        onChanged();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cargo salvo.')),
          );
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nao foi possivel salvar o cargo.')),
          );
        }
      }
    }

    Future<void> deleteRole(GroupRole role) async {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Apagar cargo?'),
          content: Text(
            'Publicações antigas mantêm o nome do cargo como "cargo à época".',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Apagar'),
            ),
          ],
        ),
      );
      if (confirm != true || !context.mounted) return;
      try {
        await repo.deleteRole(role.id);
        onChanged();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cargo apagado.')),
          );
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nao foi possivel apagar o cargo.')),
          );
        }
      }
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        if (detail.canManageRoles) ...[
          OutlinedButton.icon(
            onPressed: () => editRole(),
            icon: const Icon(Icons.add),
            label: const Text('Criar cargo'),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        for (final role in roles)
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(role.name, style: theme.textTheme.titleSmall),
                    ),
                    if (role.isSystem)
                      const RoleTag(label: 'Cargo do dono')
                    else if (detail.canManageRoles) ...[
                      IconButton(
                        onPressed: () => editRole(role: role),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                      ),
                      IconButton(
                        onPressed: () => deleteRole(role),
                        icon: const Icon(Icons.delete_outline, size: 18),
                      ),
                    ],
                  ],
                ),
                Text(
                  '${role.memberCount} membro(s)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                if (role.permissions.isEmpty)
                  Text(
                    'Sem permissões administrativas.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                    ),
                  )
                else
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: role.permissions
                        .map((p) => PermissionTag(label: permissionLabel(p)))
                        .toList(),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
