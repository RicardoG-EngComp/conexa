import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../data/group_models.dart';

const List<String> groupCategories = [
  'Centro Acadêmico',
  'Atlética',
  'Grupo de Estudos',
  'República',
  'Outros',
];

const String defaultGroupCategory = 'Outros';

String normalizeGroupCategory(String? category) {
  if (category == null) return defaultGroupCategory;
  final key = category
      .trim()
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('à', 'a')
      .replaceAll('â', 'a')
      .replaceAll('ã', 'a')
      .replaceAll('é', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ô', 'o')
      .replaceAll('õ', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ç', 'c');
  return switch (key) {
    'centro academico' => 'Centro Acadêmico',
    'atletica' => 'Atlética',
    'grupo de estudos' => 'Grupo de Estudos',
    'republica' => 'República',
    _ => defaultGroupCategory,
  };
}

String permissionLabel(String key) {
  return switch (key) {
    'manage_group' => 'Gerenciar grupo',
    'manage_roles' => 'Gerenciar cargos',
    'manage_members' => 'Gerenciar membros',
    'manage_invites' => 'Gerenciar convites',
    'post_as_group' => 'Publicar em nome do grupo',
    'moderate_content' => 'Moderar conteúdo',
    _ => key,
  };
}

class GroupAvatar extends StatelessWidget {
  const GroupAvatar({super.key, required this.name, this.radius = 20});

  final String name;
  final double radius;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.teal,
      child: Text(
        _initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.68,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class GroupSealChip extends StatelessWidget {
  const GroupSealChip({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.teal.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified_outlined, size: 14, color: AppColors.teal),
          const SizedBox(width: 5),
          Text(
            'Grupo oficial',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.teal,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class RoleTag extends StatelessWidget {
  const RoleTag({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.teal.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(color: AppColors.teal),
      ),
    );
  }
}

class PermissionTag extends StatelessWidget {
  const PermissionTag({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(color: AppColors.muted),
      ),
    );
  }
}

class InviteStatusChip extends StatelessWidget {
  const InviteStatusChip({super.key, required this.status});

  final GroupInviteStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, color) = switch (status) {
      GroupInviteStatus.active => ('Ativo', AppColors.teal),
      GroupInviteStatus.expired => ('Expirado', AppColors.muted),
      GroupInviteStatus.revoked => ('Revogado', AppColors.danger),
      GroupInviteStatus.usedUp => ('Esgotado', const Color(0xFF8A5A00)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

String formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month';
}
