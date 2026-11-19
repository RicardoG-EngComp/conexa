import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/media/media_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../features/connections/application/connection_providers.dart';
import '../../features/verification/application/verification_providers.dart';

Future<void> showAvatarMenu(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Menu do perfil',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, animation, secondaryAnimation) {
      return const SizedBox.shrink();
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final offset = Tween<Offset>(
        begin: const Offset(-1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
      return SlideTransition(
        position: offset,
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: 0.86,
            heightFactor: 1,
            child: const _AvatarMenuPanel(),
          ),
        ),
      );
    },
  );
}

class _AvatarMenuPanel extends ConsumerWidget {
  const _AvatarMenuPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profile = ref.watch(profileProvider).asData?.value;
    final connections = ref.watch(connectionsProvider).asData?.value;
    final avatar = profile?['avatar_url'] as String?;
    final name = (profile?['display_name'] as String?) ?? 'Estudante UFV';
    final course = (profile?['course'] as String?) ?? '';
    final campus = (profile?['campus'] as String?) ?? '';
    final connectionCount = connections?.accepted.length ?? 0;

    return Material(
      color: AppColors.paper,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          children: [
            Row(
              children: [
                ClipOval(
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: avatar == null || avatar.isEmpty
                        ? CircleAvatar(
                            backgroundColor: AppColors.teal,
                            child: Text(
                              _initials(name),
                              style: TextStyle(
                                color: AppColors.onPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        : MediaImage(path: avatar, width: 56, height: 56),
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Fechar',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(name, style: theme.textTheme.headlineMedium),
            const SizedBox(height: 2),
            Text(
              [course, campus].where((e) => e.isNotEmpty).join(' · '),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                Chip(
                  avatar: const Icon(Icons.verified, size: 15),
                  label: const Text('UFV'),
                  visualDensity: VisualDensity.compact,
                ),
                Chip(
                  label: Text('$connectionCount conexões'),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            const Divider(),
            _MenuItem(
              icon: Icons.person_outline,
              label: 'Perfil',
              onTap: () => _open(context, '/profile'),
            ),
            _MenuItem(
              icon: Icons.workspace_premium_outlined,
              label: 'Assinatura',
              onTap: () => _open(context, '/subscription'),
            ),
            _MenuItem(
              icon: Icons.groups_outlined,
              label: 'Meus grupos',
              onTap: () => _open(context, '/groups'),
            ),
            _MenuItem(
              icon: Icons.settings_outlined,
              label: 'Ajustes',
              onTap: () => _open(context, '/settings'),
            ),
          ],
        ),
      ),
    );
  }

  void _open(BuildContext context, String route) {
    final router = GoRouter.of(context);
    Navigator.pop(context);
    router.push(route);
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label, style: Theme.of(context).textTheme.titleSmall),
      onTap: onTap,
    );
  }
}
