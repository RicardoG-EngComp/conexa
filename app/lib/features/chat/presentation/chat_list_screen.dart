import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/time_ago.dart';
import '../application/chat_providers.dart';
import '../data/chat_models.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final conversationsAsync = ref.watch(conversationsProvider);
    final myId = Supabase.instance.client.auth.currentUser?.id;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  0,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Conversas',
                    style: theme.textTheme.displayMedium,
                  ),
                ),
              ),
              const TabBar(
                tabs: [
                  Tab(text: 'Mensagens'),
                  Tab(text: 'Pedidos'),
                ],
              ),
              Expanded(
                child: conversationsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) =>
                      const Center(child: Text('Erro ao carregar conversas.')),
                  data: (conversations) {
                    final accepted = conversations
                        .where((c) => c.status == 'accepted')
                        .toList();
                    final pending = conversations
                        .where((c) => c.status == 'pending')
                        .toList();
                    return TabBarView(
                      children: [
                        _AcceptedList(conversations: accepted),
                        _PendingList(conversations: pending, myId: myId),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AcceptedList extends ConsumerWidget {
  const _AcceptedList({required this.conversations});

  final List<ConversationSummary> conversations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(conversationsProvider);
        await ref.read(conversationsProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          if (conversations.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Text(
                'Nenhuma conversa ainda. Voce pode enviar um pedido de '
                'mensagem pelo perfil de alguem.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppColors.muted,
                ),
              ),
            ),
          for (final c in conversations)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: AppColors.teal,
                child: Icon(Icons.person, color: Colors.white),
              ),
              title: Text(c.otherName),
              subtitle: Text(
                c.lastMessage ?? 'Sem mensagens',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (c.unreadCount > 0)
                    Container(
                      margin: const EdgeInsets.only(right: AppSpacing.sm),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.teal,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${c.unreadCount}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  if (c.lastAt != null)
                    Text(
                      timeAgo(c.lastAt!),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                ],
              ),
              onTap: () => context.push('/chats/${c.id}', extra: c),
            ),
        ],
      ),
    );
  }
}

class _PendingList extends ConsumerWidget {
  const _PendingList({required this.conversations, required this.myId});

  final List<ConversationSummary> conversations;
  final String? myId;

  Future<void> _accept(
    BuildContext context,
    WidgetRef ref,
    ConversationSummary c,
  ) async {
    await ref.read(chatRepositoryProvider).acceptRequest(c.id);
    ref.invalidate(conversationsProvider);
    if (context.mounted) context.push('/chats/${c.id}', extra: c);
  }

  Future<void> _decline(
    BuildContext context,
    WidgetRef ref,
    ConversationSummary c,
  ) async {
    await ref.read(chatRepositoryProvider).declineRequest(c.id);
    ref.invalidate(conversationsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        if (conversations.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: Text(
              'Nenhum pedido de mensagem.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppColors.muted,
              ),
            ),
          ),
        for (final c in conversations)
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.otherName, style: theme.textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  c.requestMessage ?? 'Sem mensagem de apresentacao.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (c.initiatorId == myId)
                  Text(
                    'Aguardando aprovacao do outro usuario.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                    ),
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => _decline(context, ref, c),
                        child: const Text('Recusar'),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      FilledButton(
                        onPressed: () => _accept(context, ref, c),
                        child: const Text('Aceitar'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
