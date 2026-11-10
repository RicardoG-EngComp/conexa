import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/time_ago.dart';
import '../../connections/presentation/connections_list.dart';
import '../../notifications/presentation/notification_bell.dart';
import '../application/chat_providers.dart';
import '../data/chat_models.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final conversationsAsync = ref.watch(conversationsProvider);
    final myId = Supabase.instance.client.auth.currentUser?.id;
    final query = _search.text.trim().toLowerCase();

    return DefaultTabController(
      length: 3,
      initialIndex: widget.initialTab.clamp(0, 2),
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
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Conversas',
                        style: theme.textTheme.displayMedium,
                      ),
                    ),
                    const NotificationBell(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Buscar conversa...',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              const TabBar(
                tabs: [
                  Tab(text: 'Mensagens'),
                  Tab(text: 'Pedidos'),
                  Tab(text: 'Conexões'),
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
                        .where((c) {
                          if (query.isEmpty) return true;
                          return c.otherName.toLowerCase().contains(query) ||
                              (c.lastMessage ?? '').toLowerCase().contains(
                                query,
                              );
                        })
                        .toList();
                    final pending = conversations
                        .where((c) => c.status == 'pending')
                        .toList();
                    return TabBarView(
                      children: [
                        _AcceptedList(
                          conversations: accepted,
                          emptyMessage: query.isEmpty
                              ? 'Nenhuma conversa ainda. Voce pode enviar um '
                                    'pedido de mensagem pelo perfil de alguem.'
                              : 'Nenhuma conversa encontrada.',
                        ),
                        _PendingList(conversations: pending, myId: myId),
                        const ConnectionsList(),
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
  const _AcceptedList({
    required this.conversations,
    required this.emptyMessage,
  });

  final List<ConversationSummary> conversations;
  final String emptyMessage;

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
                emptyMessage,
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
    try {
      await ref.read(chatRepositoryProvider).acceptRequest(c.id);
      ref.invalidate(conversationsProvider);
      if (context.mounted) context.push('/chats/${c.id}', extra: c);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nao foi possivel aceitar o pedido.')),
        );
      }
    }
  }

  Future<void> _decline(
    BuildContext context,
    WidgetRef ref,
    ConversationSummary c,
  ) async {
    try {
      await ref.read(chatRepositoryProvider).declineRequest(c.id);
      ref.invalidate(conversationsProvider);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nao foi possivel recusar o pedido.')),
        );
      }
    }
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
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Material(
              color: AppColors.surface,
              child: InkWell(
                onTap: c.otherUserId.isEmpty
                    ? null
                    : () => context.push('/profile/${c.otherUserId}'),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              c.otherName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall,
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            size: 20,
                            color: AppColors.muted,
                          ),
                        ],
                      ),
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
                          children: [
                            Expanded(
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(0, 52),
                                ),
                                onPressed: () => _accept(context, ref, c),
                                child: const Text('Aceitar'),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 52),
                                ),
                                onPressed: () => _decline(context, ref, c),
                                child: const Text('Recusar'),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
