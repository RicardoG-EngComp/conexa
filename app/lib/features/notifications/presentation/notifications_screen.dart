import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/time_ago.dart';
import '../../../core/widgets/conexa_top_bar.dart';
import '../application/notification_providers.dart';
import '../data/notification_models.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsProvider);
    final unread = ref.watch(unreadNotificationCountProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: ConexaTopBar(
          title: 'Notificações',
          actions: [
            IconButton(
              tooltip: 'Marcar todas como lidas',
              onPressed: unread == 0
                  ? null
                  : () =>
                        ref.read(notificationRepositoryProvider).markAllRead(),
              icon: const Icon(Icons.done_all),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Tudo'),
              Tab(text: 'Menções'),
            ],
          ),
        ),
        body: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) =>
              const Center(child: Text('Erro ao carregar notificações.')),
          data: (items) {
            final mentions = items
                .where((item) => item.type == 'mention')
                .toList();
            return TabBarView(
              children: [
                _NotificationList(
                  items: items,
                  emptyMessage: 'Nenhuma notificação ainda.',
                ),
                _NotificationList(
                  items: mentions,
                  emptyMessage: 'Nenhuma menção ainda.',
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NotificationList extends ConsumerWidget {
  const _NotificationList({required this.items, required this.emptyMessage});

  final List<AppNotification> items;
  final String emptyMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: Theme.of(context).textTheme.bodyLarge
              ?.copyWith(color: AppColors.muted),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(notificationsProvider),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        itemCount: items.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) => _NotificationTile(item: items[index]),
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
        child: Icon(
          _iconFor(item.type),
          color: unread ? AppColors.onPrimary : AppColors.ink,
          size: 20,
        ),
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
    case 'connection_request':
    case 'connection_accepted':
      return Icons.people_outline;
    case 'study_pending':
    case 'study_approved':
    case 'study_rejected':
      return Icons.menu_book_outlined;
    case 'group_invite':
      return Icons.groups_outlined;
    case 'security_alert':
      return Icons.shield_outlined;
    case 'like':
      return Icons.favorite_border;
    case 'comment':
      return Icons.chat_bubble_outline;
    case 'mention':
      return Icons.alternate_email;
    case 'repost':
      return Icons.repeat;
    default:
      return Icons.notifications_outlined;
  }
}
