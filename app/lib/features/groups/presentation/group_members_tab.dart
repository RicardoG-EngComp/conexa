import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/group_providers.dart';
import '../data/group_models.dart';
import 'group_common.dart';

class GroupMembersTab extends ConsumerWidget {
  const GroupMembersTab({
    super.key,
    required this.groupId,
    required this.detail,
    required this.members,
    required this.roles,
    required this.onChanged,
  });

  final String groupId;
  final GroupDetail detail;
  final List<GroupMember> members;
  final List<GroupRole> roles;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final repo = ref.read(groupRepositoryProvider);
    final meId = Supabase.instance.client.auth.currentUser?.id;

    Future<void> run(Future<void> Function() action, String success) async {
      try {
        await action();
        onChanged();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(success)),
          );
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nao foi possivel concluir.')),
          );
        }
      }
    }

    Future<void> assignRoles(GroupMember member) async {
      final assignable = roles.where((r) => !r.isSystem).toList();
      final current = member.roles.map((r) => r.id).toSet();
      final selected = current.toSet();
      final result = await showDialog<Set<String>>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text('Cargos de ${member.name}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ninguém atribui cargo a si mesmo. Só quem gerencia cargos.',
                  style: TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final role in assignable)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(role.name),
                    value: selected.contains(role.id),
                    onChanged: (value) => setState(() {
                      if (value ?? false) {
                        selected.add(role.id);
                      } else {
                        selected.remove(role.id);
                      }
                    }),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, selected),
                child: const Text('Salvar cargos'),
              ),
            ],
          ),
        ),
      );
      if (result == null || !context.mounted) return;

      for (final role in assignable) {
        if (result.contains(role.id) && !current.contains(role.id)) {
          await repo.assignRole(groupId, member.userId, role.id);
        } else if (!result.contains(role.id) && current.contains(role.id)) {
          await repo.removeRole(groupId, member.userId, role.id);
        }
      }
      onChanged();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cargos atualizados.')),
        );
      }
    }

    Future<void> removeMember(GroupMember member) async {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Remover membro?'),
          content: Text('${member.name} deixa de publicar e ver conteúdos do grupo.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remover'),
            ),
          ],
        ),
      );
      if (confirm != true || !context.mounted) return;
      await run(
        () => repo.removeMember(groupId, member.userId),
        'Membro removido.',
      );
    }

    if (members.isEmpty) {
      return Center(
        child: Text(
          'Nenhum membro.',
          style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        for (final member in members)
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                GroupAvatar(name: member.name, radius: 18),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(member.name, style: theme.textTheme.titleSmall),
                      if (member.course.isNotEmpty)
                        Text(
                          member.course,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: member.roles
                            .map((r) => RoleTag(label: r.name))
                            .toList(),
                      ),
                    ],
                  ),
                ),
                if (member.userId != meId &&
                    (detail.canManageRoles || detail.canManageMembers))
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'roles') {
                        assignRoles(member);
                      } else if (value == 'remove' && detail.canManageMembers) {
                        removeMember(member);
                      }
                    },
                    itemBuilder: (_) => [
                      if (detail.canManageRoles)
                        const PopupMenuItem<String>(
                          value: 'roles',
                          child: Text('Atribuir cargos'),
                        ),
                      if (detail.canManageMembers)
                        const PopupMenuItem<String>(
                          value: 'remove',
                          child: Text('Remover membro'),
                        ),
                    ],
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
