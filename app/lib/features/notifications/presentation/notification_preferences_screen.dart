import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/notification_providers.dart';
import '../data/notification_models.dart';

class NotificationPreferencesScreen extends ConsumerStatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  ConsumerState<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends ConsumerState<NotificationPreferencesScreen> {
  late Future<bool> _permission;

  @override
  void initState() {
    super.initState();
    _permission = NotificationService.instance.hasPermission();
  }

  Future<void> _save(NotificationPreferences preferences) async {
    try {
      await ref
          .read(notificationRepositoryProvider)
          .savePreferences(preferences);
      ref.invalidate(notificationPreferencesProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nao foi possivel salvar as preferencias.'),
          ),
        );
      }
    }
  }

  Future<void> _requestPermission() async {
    final granted = await NotificationService.instance.requestPermission();
    if (!mounted) return;
    setState(() {
      _permission = Future.value(granted);
    });
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Permissao nao concedida. Ative nas configuracoes do Android.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prefsAsync = ref.watch(notificationPreferencesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notificacoes')),
      body: prefsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Text(
            'Erro ao carregar as preferencias.',
            style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.muted),
          ),
        ),
        data: (preferences) {
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text('Permissao', style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              FutureBuilder<bool>(
                future: _permission,
                builder: (context, snapshot) {
                  final allowed = snapshot.data ?? false;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      allowed
                          ? Icons.notifications_active_outlined
                          : Icons.notifications_off_outlined,
                    ),
                    title: Text(
                      allowed
                          ? 'Notificacoes ativas'
                          : 'Notificacoes desativadas',
                    ),
                    subtitle: Text(
                      allowed ? 'O app pode enviar avisos para este celular.' : 'Ative para receber avisos de pedidos, mensagens, conexoes e estudos.',
                    ),
                    trailing: allowed
                        ? null
                        : TextButton(
                            onPressed: _requestPermission,
                            child: const Text('Ativar'),
                          ),
                  );
                },
              ),
              const Divider(height: AppSpacing.xl),
              Text('Categorias', style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Pedidos de mensagem'),
                value: preferences.messageRequests,
                onChanged: (value) =>
                    _save(preferences.copyWith(messageRequests: value)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Mensagens'),
                value: preferences.messages,
                onChanged: (value) =>
                    _save(preferences.copyWith(messages: value)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Conexoes'),
                subtitle: const Text('Pedidos e conexoes aceitas.'),
                value: preferences.connections,
                onChanged: (value) =>
                    _save(preferences.copyWith(connections: value)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Estudos'),
                subtitle: const Text(
                  'Material aprovado, rejeitado e novos materiais pendentes.',
                ),
                value: preferences.studies,
                onChanged: (value) =>
                    _save(preferences.copyWith(studies: value)),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Categorias desligadas nao geram push nem item na central. '
                'As abas de conversas, conexoes e estudos continuam mostrando '
                'os eventos.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.muted,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
