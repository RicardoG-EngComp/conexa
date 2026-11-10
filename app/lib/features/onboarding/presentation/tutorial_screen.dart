import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/notifications/notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/tutorial_providers.dart';

class TutorialScreen extends ConsumerStatefulWidget {
  const TutorialScreen({super.key});

  @override
  ConsumerState<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends ConsumerState<TutorialScreen> {
  final _controller = PageController();
  int _index = 0;

  static const _pages = [
    _TutorialPage(
      icon: Icons.groups_outlined,
      title: 'Bem-vindo ao Conexa',
      body:
          'O Conexa e um projeto estudantil independente para a vida '
          'universitaria: comunidade, estudos, eventos e servicos do campus, '
          'comecando pela UFV. Ele e 18+ e nao tem anuncios nem venda de dados.',
    ),
    _TutorialPage(
      icon: Icons.person_outline,
      title: 'Seu perfil',
      body:
          'Nome, curso, campus e foto sao essenciais para voce aparecer na '
          'descoberta e usar todos os recursos. Bio, prompts, fotos extras e '
          'interesses sao opcionais e ajudam nas conexoes.',
    ),
    _TutorialPage(
      icon: Icons.chat_bubble_outline,
      title: 'Conexoes e conversas',
      body:
          'Conexoes comecam com um pedido. Se alguem quiser conversar sem '
          'conexao, voce recebe um pedido de mensagem e decide se aceita ou '
          'recusa. Voce pode bloquear, denunciar, limpar ou excluir conversas.',
    ),
    _TutorialPage(
      icon: Icons.menu_book_outlined,
      title: 'Estudos',
      body:
          'Encontre disciplinas, materiais, votos de utilidade e links uteis. '
          'O envio de materiais e restrito aos convidados do piloto e passa '
          'por aprovacao antes de aparecer para todos.',
    ),
    _TutorialPage(
      icon: Icons.shield_outlined,
      title: 'Seguranca e beta',
      body:
          'Voce controla privacidade, bloqueios, denuncias e notificacoes. '
          'O beta e instalado pelo Firebase App Tester e evolui a cada '
          'atualizacao. Seu feedback define as proximas prioridades.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await setTutorialSeen();
    ref.invalidate(tutorialSeenProvider);
    if (mounted) context.go('/feed');
  }

  void _next() {
    if (_index == _pages.length - 1) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLast = _index == _pages.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: _finish, child: const Text('Pular')),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (index) => setState(() => _index = index),
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: AppColors.teal,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Icon(page.icon, color: Colors.white, size: 36),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        Text(page.title, style: theme.textTheme.displaySmall),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          page.body,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                0,
                AppSpacing.xl,
                AppSpacing.xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages.length, (index) {
                      final active = index == _index;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: active ? 22 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: active ? AppColors.teal : AppColors.border,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (isLast)
                    OutlinedButton.icon(
                      onPressed: () async {
                        final granted = await NotificationService.instance
                            .requestPermission();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                granted ? 'Notificacoes ativadas.' : 'Ative as notificacoes nas configuracoes do Android.',
                              ),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.notifications_outlined),
                      label: const Text('Ativar notificacoes'),
                    ),
                  if (isLast) const SizedBox(height: AppSpacing.sm),
                  FilledButton(
                    onPressed: _next,
                    child: Text(isLast ? 'Comecar a usar' : 'Proximo'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TutorialPage {
  const _TutorialPage({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}
