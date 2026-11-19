import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/verification/application/verification_providers.dart';
import '../media/media_image.dart';
import '../theme/app_colors.dart';
import '../widgets/avatar_menu.dart';
import '../widgets/ribbon_icon.dart';

class ConexaTopBar extends ConsumerWidget implements PreferredSizeWidget {
  const ConexaTopBar({
    super.key,
    this.title,
    this.showLogo = false,
    this.bottom,
    this.actions = const [],
  });

  final String? title;
  final bool showLogo;
  final PreferredSizeWidget? bottom;
  final List<Widget> actions;

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).asData?.value;
    final avatar = profile?['avatar_url'] as String?;
    final name = (profile?['display_name'] as String?) ?? 'Estudante UFV';

    return AppBar(
      automaticallyImplyLeading: false,
      leadingWidth: 62,
      leading: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Tooltip(
          message: 'Abrir menu do perfil',
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => showAvatarMenu(context),
            child: ClipOval(
              child: SizedBox(
                width: 36,
                height: 36,
                child: avatar == null || avatar.isEmpty
                    ? CircleAvatar(
                        backgroundColor: AppColors.teal,
                        child: Text(
                          _initials(name),
                          style: TextStyle(
                            color: AppColors.onPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    : MediaImage(path: avatar, width: 36, height: 36),
              ),
            ),
          ),
        ),
      ),
      centerTitle: true,
      title: showLogo
          ? Text(
              'Conexa',
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(color: AppColors.ink),
            )
          : Text(title ?? '', style: Theme.of(context).textTheme.titleLarge),
      actions: [
        ...actions,
        IconButton(
          tooltip: 'Pessoas e conexões',
          onPressed: () => context.push('/people'),
          icon: const RibbonIcon('people_add', size: 24),
        ),
        const SizedBox(width: 4),
      ],
      bottom: bottom,
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}
