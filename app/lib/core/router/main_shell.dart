import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/chat/application/chat_providers.dart';
import '../../features/chat/data/chat_models.dart';
import '../../features/notifications/application/notification_providers.dart';
import '../../features/onboarding/application/tutorial_providers.dart';
import '../../features/verification/application/verification_providers.dart';
import '../theme/app_colors.dart';
import '../widgets/ribbon_icon.dart';

class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.child});

  final Widget child;

  static const _paths = [
    '/feed',
    '/discover',
    '/map',
    '/notifications',
    '/chats',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final tutorialSeenAsync = ref.watch(tutorialSeenProvider);

    return profileAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) =>
          const Scaffold(body: Center(child: Text('Erro ao carregar perfil.'))),
      data: (profile) {
        if (tutorialSeenAsync.asData?.value == false) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go('/tutorial');
          });
        }
        final accountStatus =
            (profile?['account_status'] as String?) ?? 'active';
        if (accountStatus != 'active') {
          return Scaffold(
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.block, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        accountStatus == 'banned'
                            ? 'Sua conta foi banida.'
                            : 'Sua conta esta suspensa.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Entre em contato com a administracao.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        final status =
            (profile?['verification_status'] as String?) ?? 'unverified';
        final ufvEmail = (profile?['ufv_email'] as String? ?? '').toLowerCase();
        final verified =
            status == 'verified' || ufvEmail.endsWith('@alunos.ufv.br');
        if (!verified) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go('/verification');
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final location = GoRouterState.of(context).uri.path;
        final index = _paths.indexWhere((p) => location.startsWith(p));
        final selected = index < 0 ? 0 : index;

        return Scaffold(
          body: child,
          bottomNavigationBar: _HubNavigationBar(selected: selected),
        );
      },
    );
  }
}

class _HubNavigationBar extends ConsumerWidget {
  const _HubNavigationBar({required this.selected});

  final int selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationCount = ref.watch(unreadNotificationCountProvider);
    final conversations =
        ref.watch(conversationsProvider).asData?.value ??
        const <ConversationSummary>[];
    final chatCount = conversations.fold<int>(
      0,
      (sum, conversation) => sum + conversation.unreadCount,
    );

    return NavigationBarTheme(
      data: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final active = states.contains(WidgetState.selected);
          return IconThemeData(
            color: active ? AppColors.primary : AppColors.ink,
            size: 26,
          );
        }),
      ),
      child: NavigationBar(
        height: 64,
        selectedIndex: selected,
        onDestinationSelected: (i) => context.go(MainShell._paths[i]),
        destinations: [
          NavigationDestination(
            icon: const RibbonIcon('feed', size: 26),
            selectedIcon: RibbonIcon(
              'feed',
              size: 26,
              color: AppColors.primary,
            ),
            label: 'Feed',
          ),
          NavigationDestination(
            icon: const RibbonIcon('search', size: 26),
            selectedIcon: RibbonIcon(
              'search',
              size: 26,
              color: AppColors.primary,
            ),
            label: 'Buscar',
          ),
          NavigationDestination(
            icon: const RibbonIcon('map', size: 26),
            selectedIcon: RibbonIcon('map', size: 26, color: AppColors.primary),
            label: 'Mapa',
          ),
          NavigationDestination(
            icon: Badge.count(
              count: notificationCount,
              isLabelVisible: notificationCount > 0,
              child: const RibbonIcon('bell', size: 26),
            ),
            selectedIcon: Badge.count(
              count: notificationCount,
              isLabelVisible: notificationCount > 0,
              child: RibbonIcon('bell', size: 26, color: AppColors.primary),
            ),
            label: 'Notificações',
          ),
          NavigationDestination(
            icon: Badge.count(
              count: chatCount,
              isLabelVisible: chatCount > 0,
              child: const RibbonIcon('chat', size: 26),
            ),
            selectedIcon: Badge.count(
              count: chatCount,
              isLabelVisible: chatCount > 0,
              child: RibbonIcon('chat', size: 26, color: AppColors.primary),
            ),
            label: 'Chat',
          ),
        ],
      ),
    );
  }
}
