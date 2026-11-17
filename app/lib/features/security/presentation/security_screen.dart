import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/notifications/notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/time_ago.dart';
import '../application/security_providers.dart';

class SecurityScreen extends ConsumerStatefulWidget {
  const SecurityScreen({super.key});

  @override
  ConsumerState<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends ConsumerState<SecurityScreen> {
  bool _exporting = false;

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final data = await ref.read(securityRepositoryProvider).exportMyData();
      final json = const JsonEncoder.withIndent('  ').convert(data);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Meus dados'),
          content: SizedBox(
            width: double.maxFinite,
            height: 360,
            child: SingleChildScrollView(
              child: SelectableText(json, style: const TextStyle(fontSize: 11)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: json));
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Dados copiados.')),
                  );
                }
              },
              child: const Text('Copiar'),
            ),
            FilledButton.icon(
              onPressed: () async {
                try {
                  final dir = await getTemporaryDirectory();
                  final file = File(
                    '${dir.path}/conexa-dados-'
                    '${DateTime.now().millisecondsSinceEpoch}.json',
                  );
                  await file.writeAsString(json);
                  await SharePlus.instance.share(
                    ShareParams(
                      files: [XFile(file.path)],
                      subject: 'Meus dados Conexa',
                    ),
                  );
                } catch (_) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Nao foi possivel compartilhar o arquivo.',
                        ),
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.ios_share),
              label: const Text('Compartilhar arquivo'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Fechar'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nao foi possivel exportar os dados.')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _signOutEverywhere() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sair de todos os dispositivos?'),
        content: const Text(
          'Todas as sessoes serao encerradas, inclusive neste aparelho.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sair de todos'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await NotificationService.instance.unregisterCurrentToken();
    } catch (_) {}
    try {
      await ref.read(securityRepositoryProvider).signOutEverywhere();
    } catch (_) {}
    if (mounted) context.go('/welcome');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final devices = ref.watch(devicesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Seguranca e privacidade')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text('Conta', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.devices_outlined),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Dispositivos conhecidos',
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Historico de aparelhos que acessaram sua conta.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Privacidade', style: theme.textTheme.titleSmall),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.volume_off_outlined),
            title: const Text('Usuarios silenciados'),
            subtitle: const Text('Nao ver posts e comentarios dessas pessoas.'),
            onTap: () => context.push('/muted-users'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.text_fields_outlined),
            title: const Text('Palavras silenciadas'),
            subtitle: const Text('Nao ver posts que contenham esses termos.'),
            onTap: () => context.push('/muted-words'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.report_outlined),
            title: const Text('Meus relatos'),
            subtitle: const Text('Acompanhe denuncias e envie apelacao.'),
            onTap: () => context.push('/my-reports'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.download_outlined),
            title: const Text('Exportar meus dados'),
            subtitle: const Text('Copia um JSON com os dados da sua conta.'),
            trailing: _exporting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: _exporting ? null : _export,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Dispositivos', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          devices.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => const Text('Erro ao carregar dispositivos.'),
            data: (rows) {
              if (rows.isEmpty) {
                return Text(
                  'Nenhum dispositivo registrado ainda.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                  ),
                );
              }
              return Column(
                children: [
                  for (final row in rows)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.devices_outlined),
                      title: Text((row['label'] as String?) ?? 'Dispositivo'),
                      subtitle: Text(
                        'Ultimo acesso: ${timeAgo(DateTime.parse(row['last_seen_at'] as String))}',
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: _signOutEverywhere,
            icon: const Icon(Icons.logout),
            label: const Text('Sair de todos os dispositivos'),
          ),
        ],
      ),
    );
  }
}
