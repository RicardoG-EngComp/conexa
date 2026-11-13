import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/legal_urls.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  Future<void> _open(BuildContext context, String url) async {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Ajuda e FAQ')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text('Como funciona o Conexa', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.slideshow_outlined),
            title: const Text('Ver o tutorial novamente'),
            subtitle: const Text('Passo a passo das principais areas.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/tutorial'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Notificacoes'),
            subtitle: const Text('Ativar, desativar e escolher categorias.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/notification-preferences'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.checklist_outlined),
            title: const Text('Checklist do perfil'),
            subtitle: const Text('O que falta para completar seu perfil.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/profile-checklist'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.feedback_outlined),
            title: const Text('Feedback e sugestões'),
            subtitle: const Text(
              'Relate um problema ou sugira uma melhoria no aplicativo.',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/feedback'),
          ),
          const Divider(height: AppSpacing.xl),
          Text('Duvidas frequentes', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          const _Faq(
            title: 'Como faco uma conexao?',
            body:
                'Abra o perfil de alguem e envie uma solicitacao. A outra '
                'pessoa pode aceitar ou recusar. Conexoes aceitas aparecem em '
                'Conversas > Conexoes.',
          ),
          const _Faq(
            title: 'Como funciona o pedido de mensagem?',
            body:
                'Se voce ainda nao tem conexao com a pessoa, o primeiro '
                'contato vira um pedido. Ela decide se aceita ou recusa. Isso '
                'evita mensagens sem consentimento.',
          ),
          const _Faq(
            title: 'Posso apagar uma conversa?',
            body:
                'Sim. No topo da conversa, toque em ⋮ para limpar ou excluir '
                'so para voce. Para apagar uma mensagem para todos, use o toque '
                'longo em uma mensagem que voce enviou, dentro de 5 minutos.',
          ),
          const _Faq(
            title: 'Como envio material de estudo?',
            body:
                'O envio e restrito aos convidados do piloto. O material passa '
                'por aprovacao antes de aparecer para todos. Voce acompanha o '
                'status pelo proprio app.',
          ),
          const _Faq(
            title: 'O que acontece se eu bloquear alguem?',
            body:
                'A pessoa deixa de aparecer para voce e voce deixa de aparecer '
                'para ela. Voce pode revisar a lista em Ajustes > Usuarios '
                'bloqueados.',
          ),
          const _Faq(
            title: 'O app e oficial da UFV?',
            body:
                'Nao. O Conexa e um projeto estudantil independente, sem '
                'vinculo oficial com a UFV. Ele e destinado a maiores de 18 '
                'anos.',
          ),
          const Divider(height: AppSpacing.xl),
          Text('Politicas e contato', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Politica de Privacidade'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => _open(context, LegalUrls.privacy),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.description_outlined),
            title: const Text('Termos de Uso'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => _open(context, LegalUrls.terms),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.groups_outlined),
            title: const Text('Diretrizes da Comunidade'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => _open(context, LegalUrls.guidelines),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.delete_outline),
            title: const Text('Exclusao de conta'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => _open(context, LegalUrls.accountDeletion),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.mail_outline),
            title: const Text('Falar com o suporte'),
            subtitle: const Text('conexa.projeto@gmail.com'),
            onTap: () => _open(
              context,
              'mailto:conexa.projeto@gmail.com?subject=Ajuda%20Conexa',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Projeto independente, 18+. Sem anuncios e sem venda de dados.',
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _Faq extends StatelessWidget {
  const _Faq({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: AppSpacing.md),
      title: Text(title, style: theme.textTheme.bodyLarge),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          ),
        ),
      ],
    );
  }
}
