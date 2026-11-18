import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/time_ago.dart';
import '../../connections/application/connection_providers.dart';
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
  bool _showArchived = false;
  bool _creatingGroup = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _createGroup() async {
    final connections = await ref.read(connectionsProvider.future);
    if (!mounted) return;
    final selected = <String>{};
    final title = TextEditingController();
    final result = await showDialog<({String title, Set<String> members})>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Novo grupo'),
          content: SizedBox(
            width: double.maxFinite,
            height: 380,
            child: Column(
              children: [
                TextField(
                  controller: title,
                  maxLength: 80,
                  decoration: const InputDecoration(labelText: 'Nome do grupo'),
                ),
                const SizedBox(height: AppSpacing.sm),
                Expanded(
                  child: connections.accepted.isEmpty
                      ? const Center(
                          child: Text('Adicione conexoes para criar um grupo.'),
                        )
                      : ListView(
                          children: [
                            for (final c in connections.accepted)
                              CheckboxListTile(
                                value: selected.contains(c.userId),
                                title: Text(c.displayName),
                                onChanged: (value) {
                                  setDialogState(() {
                                    if (value == true) {
                                      if (selected.length < 20) {
                                        selected.add(c.userId);
                                      }
                                    } else {
                                      selected.remove(c.userId);
                                    }
                                  });
                                },
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final name = title.text.trim();
                if (name.length < 3 || selected.isEmpty) return;
                Navigator.pop(ctx, (title: name, members: selected));
              },
              child: const Text('Criar'),
            ),
          ],
        ),
      ),
    );
    title.dispose();
    if (result == null) return;

    setState(() => _creatingGroup = true);
    try {
      final id = await ref
          .read(chatRepositoryProvider)
          .createGroupConversation(result.title, result.members.toList());
      ref.invalidate(conversationsProvider);
      if (mounted) context.push('/chats/$id');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nao foi possivel criar o grupo.')),
        );
      }
    } finally {
      if (mounted) setState(() => _creatingGroup = false);
    }
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
                    IconButton(
                      tooltip: _showArchived
                          ? 'Mostrar conversas ativas'
                          : 'Mostrar arquivadas',
                      onPressed: () =>
                          setState(() => _showArchived = !_showArchived),
                      icon: Icon(
                        _showArchived
                            ? Icons.unarchive_outlined
                            : Icons.archive_outlined,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Novo grupo',
                      onPressed: _creatingGroup ? null : _createGroup,
                      icon: _creatingGroup
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.group_add_outlined),
                    ),
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
                        .where((c) => _showArchived ? c.archived : !c.archived)
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
                          emptyMessage: _showArchived
                              ? 'Nenhuma conversa arquivada.'
                              : query.isEmpty
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
              leading: CircleAvatar(
                backgroundColor: AppColors.teal,
                child: Icon(
                  c.isGroup ? Icons.groups_outlined : Icons.person,
                  color: AppColors.onPrimary,
                ),
              ),
              title: Row(
                children: [
                  Flexible(
                    child: Text(
                      c.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (c.pinned) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.push_pin, size: 13),
                  ],
                  if (c.muted) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.notifications_off_outlined,
                      size: 14,
                      color: AppColors.muted,
                    ),
                  ],
                ],
              ),
              subtitle: Text(
                c.isGroup
                    ? '${c.memberCount} participantes · ${c.lastMessage ?? 'Sem mensagens'}'
                    : (c.lastMessage ?? 'Sem mensagens'),
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
                          color: AppColors.onPrimary,
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
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.more_vert, size: 18),
                    onSelected: (value) async {
                      final repo = ref.read(chatRepositoryProvider);
                      try {
                        switch (value) {
                          case 'pin':
                            await repo.setPinned(c.id, !c.pinned);
                          case 'mute':
                            await repo.setMuted(c.id, !c.muted);
                          case 'archive':
                            await repo.setArchived(c.id, !c.archived);
                        }
                        ref.invalidate(conversationsProvider);
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Nao foi possivel atualizar.'),
                            ),
                          );
                        }
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'pin',
                        child: Text(c.pinned ? 'Desafixar' : 'Fixar'),
                      ),
                      PopupMenuItem(
                        value: 'mute',
                        child: Text(c.muted ? 'Reativar' : 'Silenciar'),
                      ),
                      PopupMenuItem(
                        value: 'archive',
                        child: Text(c.archived ? 'Desarquivar' : 'Arquivar'),
                      ),
                    ],
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
                          Icon(
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
