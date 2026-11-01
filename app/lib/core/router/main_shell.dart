import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/verification/application/verification_providers.dart';

class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.child});

  final Widget child;

  static const _paths = ['/feed', '/discover', '/chats', '/coach', '/settings'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);

    return profileAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) =>
          const Scaffold(body: Center(child: Text('Erro ao carregar perfil.'))),
      data: (profile) {
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

        final profileComplete =
            ((profile?['display_name'] as String?)?.trim().isNotEmpty ??
                false) &&
            ((profile?['course'] as String?)?.trim().isNotEmpty ?? false) &&
            ((profile?['avatar_url'] as String?)?.trim().isNotEmpty ?? false);
        if (!profileComplete) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go('/profile-setup');
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
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
          bottomNavigationBar: NavigationBar(
            selectedIndex: selected,
            onDestinationSelected: (i) => context.go(_paths[i]),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Feed',
              ),
              NavigationDestination(
                icon: Icon(Icons.explore_outlined),
                selectedIcon: Icon(Icons.explore),
                label: 'Descobrir',
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
