import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/legal_urls.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../auth/application/auth_providers.dart';
import '../../profile/application/profile_providers.dart';
import '../../reports/application/report_providers.dart';
import '../../verification/application/verification_providers.dart';
import '../data/account_repository.dart';

Future<void> _openLegal(BuildContext context, String url) async {
  final opened = await launchUrl(
    Uri.parse(url),
    mode: LaunchMode.externalApplication,
  );
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Nao foi possivel abrir o link.')),
    );
  }
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isAdminAsync = ref.watch(isAdminProvider);
    final profileAsync = ref.watch(profileProvider);
    final isPrivate = profileAsync.asData?.value?['profile_private'] == true;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text('Ajustes', style: theme.textTheme.displayMedium),
            const SizedBox(height: AppSpacing.lg),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_outline),
              title: const Text('Meu perfil'),
              onTap: () => context.push('/profile'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.password_outlined),
              title: const Text('Alterar senha'),
              onTap: () => context.push('/change-password'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.lock_outline),
              title: const Text('Perfil privado'),
              subtitle: const Text(
                'Seu feed fica visivel apenas para conexoes aceitas.',
              ),
              value: isPrivate,
              onChanged: (value) async {
                await ref.read(profileRepositoryProvider).updateProfile({
                  'profile_private': value,
                });
                ref.invalidate(profileProvider);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Politica de Privacidade'),
              onTap: () => _openLegal(context, LegalUrls.privacy),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.description_outlined),
              title: const Text('Termos de Uso'),
              onTap: () => _openLegal(context, LegalUrls.terms),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.groups_outlined),
              title: const Text('Diretrizes da Comunidade'),
              onTap: () => _openLegal(context, LegalUrls.guidelines),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.copyright_outlined),
              title: const Text('Direitos autorais e remocao'),
              onTap: () => _openLegal(context, LegalUrls.copyright),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.block_outlined),
              title: const Text('Usuarios bloqueados'),
              onTap: () => context.push('/blocked-users'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.delete_outline),
              title: const Text('Excluir conta'),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Excluir conta?'),
                    content: const Text(
                      'Todos os dados da conta, fotos, posts e mensagens '
                      'serao apagados. Esta acao nao pode ser desfeita.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancelar'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Excluir'),
                      ),
                    ],
                  ),
                );
                if (confirm != true || !context.mounted) return;

                try {
                  await ref.read(accountRepositoryProvider).deleteAccount();
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Nao foi possivel excluir a conta.'),
                      ),
                    );
                  }
                  return;
                }

                try {
                  await ref.read(authRepositoryProvider).signOut();
                } catch (_) {}
                if (context.mounted) context.go('/welcome');
              },
            ),
            if (isAdminAsync.asData?.value ?? false) ...[
              const Divider(height: AppSpacing.xl),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.admin_panel_settings_outlined),
                title: const Text('Administracao'),
                subtitle: Text(
                  'Denuncias e moderacao',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
                onTap: () => context.push('/admin'),
              ),
            ],
            const Divider(height: AppSpacing.xl),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.logout, color: AppColors.danger),
              title: const Text('Sair da conta'),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Sair da conta?'),
                    content: const Text('Voce precisara entrar novamente.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancelar'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Sair'),
                      ),
                    ],
                  ),
                );
                if (confirm != true) return;
                await ref.read(authRepositoryProvider).signOut();
                if (context.mounted) context.go('/welcome');
              },
            ),
          ],
        ),
      ),
    );
  }
}
