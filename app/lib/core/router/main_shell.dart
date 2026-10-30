import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/verification/application/verification_providers.dart';

class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.child});

  final Widget child;

  static const _paths = [
    '/discover',
    '/matches',
    '/chats',
    '/coach',
    '/settings',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);

    return profileAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) =>
          const Scaffold(body: Center(child: Text('Erro ao carregar perfil.'))),
      data: (profile) {
        final status =
            (profile?['verification_status'] as String?) ?? 'unverified';
        if (status != 'verified') {
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
          bottomNavigationBar: NavigationBar(
            selectedIndex: selected,
            onDestinationSelected: (i) => context.go(_paths[i]),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.explore_outlined),
                selectedIcon: Icon(Icons.explore),
                label: 'Descobrir',
              ),
              NavigationDestination(
                icon: Icon(Icons.favorite_outline),
                selectedIcon: Icon(Icons.favorite),
                label: 'Curtidas',
              ),
              NavigationDestination(
                icon: Icon(Icons.chat_bubble_outline),
                selectedIcon: Icon(Icons.chat_bubble),
                label: 'Conversas',
              ),
              NavigationDestination(
                icon: Icon(Icons.auto_awesome_outlined),
                selectedIcon: Icon(Icons.auto_awesome),
                label: 'Coach',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: 'Ajustes',
              ),
            ],
          ),
        );
      },
    );
  }
}
