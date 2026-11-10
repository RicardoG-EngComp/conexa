import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  State<AdminNotificationsScreen> createState() =>
      _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final result = await Supabase.instance.client.rpc(
      'admin_notification_diagnostics',
      params: {'p_limit': 20},
    );
    return (result as Map).cast<String, dynamic>();
  }

  void _refresh() {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostico de notificacoes'),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  'Nao foi possivel carregar o diagnostico.\n'
                  '${snapshot.error}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
              ),
            );
          }

          final data = snapshot.data ?? const <String, dynamic>{};
          final pending = data['pending'] ?? 0;
          final sent = data['sent'] ?? 0;
          final failed = data['failed'] ?? 0;
          final tokens = data['tokens'] ?? 0;
          final errors = (data['recent_errors'] as List?) ?? const [];
          final recentTokens = (data['recent_tokens'] as List?) ?? const [];

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  _Metric(label: 'Pendentes', value: '$pending'),
                  _Metric(label: 'Enviadas', value: '$sent'),
                  _Metric(label: 'Com erro', value: '$failed'),
                  _Metric(label: 'Tokens', value: '$tokens'),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Falhas recentes', style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              if (errors.isEmpty)
                Text(
                  'Nenhuma falha recente.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                  ),
                )
              else
                ...errors.map((item) {
                  final map = (item as Map).cast<String, dynamic>();
                  return Card(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: ListTile(
                      title: Text('${map['type']}'),
                      subtitle: Text(
                        '${map['error']}\n'
                        'Tentativas: ${map['attempts']} | ${map['created_at']}',
                      ),
                    ),
                  );
                }),
              const Divider(height: AppSpacing.xl),
              Text('Tokens recentes', style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              if (recentTokens.isEmpty)
                Text(
                  'Nenhum token registrado.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                  ),
                )
              else
                ...recentTokens.map((item) {
                  final map = (item as Map).cast<String, dynamic>();
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.phone_android),
                    title: Text('Token final ${map['token_masked']}'),
                    subtitle: Text(
                      '${map['platform']} | ultimo uso: ${map['last_seen_at']}',
                    ),
                  );
                }),
              const SizedBox(height: AppSpacing.md),
              Text(
                'O token completo fica apenas no painel do Supabase. '
                'Nenhum conteudo de mensagem aparece aqui.',
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

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 150,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: AppColors.teal,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
