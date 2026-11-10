import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/group_providers.dart';

class JoinGroupScreen extends ConsumerStatefulWidget {
  const JoinGroupScreen({super.key, required this.token});

  final String token;

  @override
  ConsumerState<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends ConsumerState<JoinGroupScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _join() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final groupId = await ref
          .read(groupRepositoryProvider)
          .redeemInvite(widget.token);
      ref.invalidate(myGroupsProvider);
      if (mounted) {
        context.go('/groups');
        context.push('/groups/$groupId');
      }
    } catch (e) {
      setState(() {
        _error = _friendly(e.toString());
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendly(String raw) {
    if (raw.contains('convite expirado')) return 'Este convite expirou.';
    if (raw.contains('convite revogado')) return 'Este convite foi revogado.';
    if (raw.contains('convite esgotado')) return 'Este convite atingiu o limite de usos.';
    if (raw.contains('convite invalido')) return 'Convite inválido.';
    if (raw.contains('nao_verificado')) return 'Sua conta precisa estar verificada.';
    if (raw.contains('diretrizes_necessarias')) {
      return 'Aceite as Diretrizes da Comunidade para continuar.';
    }
    if (raw.contains('token invalido')) return 'Código do convite inválido.';
    return 'Não foi possível entrar no grupo.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Convite de grupo')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.groups_outlined,
                    size: 48,
                    color: AppColors.teal,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Você recebeu um convite',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Entre no grupo por este link. O convite pode ter validade e '
                    'limite de usos.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.danger,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton(
                    onPressed: _busy ? null : _join,
                    child: _busy
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Entrar no grupo'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
