import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/time_ago.dart';
import '../application/notification_providers.dart';
import '../data/notification_models.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(notificationsProvider);
    final unread = ref.watch(unreadNotificationCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificacoes'),
        actions: [
          TextButton(
            onPressed: unread == 0
                ? null
                : () => ref.read(notificationRepositoryProvider).markAllRead(),
            child: const Text('Marcar todas'),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Text(
            'Erro ao carregar notificacoes.',
            style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.muted),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Text(
                'Nenhuma notificacao ainda.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppColors.muted,
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(notificationsProvider);
            },
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                return _NotificationTile(item: items[index]);
              },
            ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.item});

  final AppNotification item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final unread = item.isUnread;

    return ListTile(
      tileColor: unread ? AppColors.surface : null,
      leading: CircleAvatar(
        backgroundColor: unread ? AppColors.teal : AppColors.border,
        child: Icon(_iconFor(item.type), color: Colors.white, size: 20),
      ),
      title: Text(
        item.title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      subtitle: Text(
        item.body,
        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
      ),
      trailing: Text(
        timeAgo(item.createdAt),
        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
      ),
      onTap: () async {
        if (unread) {
          try {
            await ref.read(notificationRepositoryProvider).markRead(item.id);
          } catch (_) {}
        }
        final route = item.route;
        if (route != null && route.isNotEmpty && context.mounted) {
          context.push(route);
        }
      },
    );
  }
}

IconData _iconFor(String type) {
  switch (type) {
    case 'message':
      return Icons.chat_bubble_outline;
    case 'message_request':
      return Icons.mark_email_unread_outlined;
    case 'connection_request':
    case 'connection_accepted':
      return Icons.people_outline;
    case 'study_pending':
    case 'study_approved':
    case 'study_rejected':
      return Icons.menu_book_outlined;
    case 'group_invite':
      return Icons.groups_outlined;
    default:
      return Icons.notifications_outlined;
  }
}
