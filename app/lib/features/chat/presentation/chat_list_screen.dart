import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/time_ago.dart';
import '../application/chat_providers.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final conversationsAsync = ref.watch(conversationsProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(conversationsProvider);
            await ref.read(conversationsProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text('Conversas', style: theme.textTheme.displayMedium),
              const SizedBox(height: AppSpacing.md),
              ...conversationsAsync.when<List<Widget>>(
                data: (conversations) {
                  if (conversations.isEmpty) {
                    return [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.xl,
                        ),
                        child: Text(
                          'Nenhuma conversa ainda. No feed, toque em um post '
                          'e escolha "Mensagem" para comecar.',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                    ];
                  }
                  return conversations
                      .map(
                        (c) => ListTile(
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
                          trailing: c.lastAt == null
                              ? null
                              : Text(
                                  timeAgo(c.lastAt!),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.muted,
                                  ),
                                ),
                          onTap: () => context.push('/chats/${c.id}', extra: c),
                        ),
                      )
                      .toList();
                },
                loading: () => [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
                error: (_, _) => [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                    child: Text('Erro ao carregar conversas.'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
