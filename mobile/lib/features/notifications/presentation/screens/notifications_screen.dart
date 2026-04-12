import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/notifications_provider.dart';
import '../../domain/notification_model.dart';
import '../../../../theme/app_colors.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            const Text('התראות'),
            if (state.unreadCount > 0) ...[
              const SizedBox(width: 8),
              _Badge(count: state.unreadCount),
            ],
          ],
        ),
        backgroundColor: AppColors.background,
        automaticallyImplyLeading: false,
        actions: [
          if (state.unreadCount > 0)
            TextButton(
              onPressed: () =>
                  ref.read(notificationsProvider.notifier).markAllRead(),
              child: const Text('סמן הכל כנקרא'),
            ),
          IconButton(
            onPressed: () =>
                ref.read(notificationsProvider.notifier).load(),
            icon: const Icon(Icons.refresh_outlined),
          ),
        ],
      ),
      body: _buildBody(context, ref, state),
    );
  }

  Widget _buildBody(
      BuildContext context, WidgetRef ref, NotificationsState state) {
    if (state.isLoading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.textDisabled),
            const SizedBox(height: 12),
            const Text('שגיאה בטעינת התראות'),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () =>
                  ref.read(notificationsProvider.notifier).load(),
              child: const Text('נסה שוב'),
            ),
          ],
        ),
      );
    }

    if (state.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_outlined,
                size: 64, color: AppColors.textDisabled),
            const SizedBox(height: 16),
            const Text(
              'אין התראות עדיין',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              'כשחברי הקבוצה יוסיפו הוצאות\nתקבל התראה כאן',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textSecondary.withOpacity(0.7),
                  fontSize: 14),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(notificationsProvider.notifier).load(),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: state.items.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, indent: 72, endIndent: 16),
        itemBuilder: (context, i) {
          final notif = state.items[i];
          return _NotificationTile(
            notification: notif,
            onTap: () {
              if (!notif.isRead) {
                ref.read(notificationsProvider.notifier).markRead(notif.id);
              }
            },
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationTile({required this.notification, required this.onTap});

  IconData _icon() {
    switch (notification.type) {
      case 'new_expense':
        return Icons.receipt_outlined;
      case 'settlement_requested':
        return Icons.payment_outlined;
      case 'settlement_confirmed':
        return Icons.check_circle_outline;
      case 'member_joined':
        return Icons.person_add_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _iconColor() {
    switch (notification.type) {
      case 'new_expense':
        return AppColors.primary;
      case 'settlement_requested':
        return AppColors.warning;
      case 'settlement_confirmed':
        return AppColors.positive;
      case 'member_joined':
        return AppColors.secondary;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = !notification.isRead;

    return InkWell(
      onTap: onTap,
      child: Container(
        color: unread
            ? AppColors.primary.withOpacity(0.04)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon circle
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _iconColor().withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(_icon(), color: _iconColor(), size: 22),
            ),

            const SizedBox(width: 14),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            fontWeight: unread
                                ? FontWeight.w700
                                : FontWeight.w500,
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        notification.timeAgo,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.body,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Unread dot
            if (unread)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 4, top: 4),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final int count;
  const _Badge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
