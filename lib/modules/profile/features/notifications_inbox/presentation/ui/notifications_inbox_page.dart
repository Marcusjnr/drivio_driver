import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/commons/types/notification_item.dart';
import 'package:drivio_driver/modules/profile/features/notifications_inbox/presentation/logic/controller/notifications_inbox_controller.dart';

class NotificationsInboxPage extends ConsumerWidget {
  const NotificationsInboxPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NotificationsInboxState state =
        ref.watch(notificationsInboxControllerProvider);
    final NotificationsInboxController c =
        ref.read(notificationsInboxControllerProvider.notifier);

    return ScreenScaffold(
      child: Column(
        children: <Widget>[
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: context.border)),
            ),
            child: Row(
              children: <Widget>[
                BackButtonBox(onTap: () => AppNavigation.pop()),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Notifications',
                    style: AppTextStyles.h2.copyWith(color: context.text),
                  ),
                ),
                if (state.unreadCount > 0)
                  TextButton(
                    onPressed: c.markAllRead,
                    child: Text(
                      'Mark all read',
                      style: TextStyle(
                        color: context.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: c.refresh,
              child: state.isLoading && state.items.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : state.items.isEmpty
                      ? _Empty(error: state.error)
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: state.items.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            color: context.border,
                          ),
                          itemBuilder: (_, int i) =>
                              _Row(item: state.items[i], onTap: c.markRead),
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({this.error});
  final String? error;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: <Widget>[
        const SizedBox(height: 80),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: <Widget>[
                const Text('🔔', style: TextStyle(fontSize: 36)),
                const SizedBox(height: 10),
                Text(
                  error ?? "You're all caught up.",
                  style:
                      AppTextStyles.bodySm.copyWith(color: context.textDim),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.item, required this.onTap});

  final NotificationItem item;
  final void Function(NotificationItem) onTap;

  @override
  Widget build(BuildContext context) {
    final bool unread = item.isUnread;
    final (String emoji, Color tone) = _categoryStyle(context, item.category);
    return InkWell(
      onTap: () => onTap(item),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        color: unread ? context.accent.withValues(alpha: 0.05) : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(emoji, style: const TextStyle(fontSize: 16)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 13,
                            color: context.text,
                            fontWeight: unread
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _fmtTime(item.createdAt),
                        style: TextStyle(
                            fontSize: 10, color: context.textMuted),
                      ),
                    ],
                  ),
                  if (item.body != null) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      item.body!,
                      style:
                          TextStyle(fontSize: 12, color: context.textDim),
                    ),
                  ],
                ],
              ),
            ),
            if (unread) ...<Widget>[
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.accent,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static (String, Color) _categoryStyle(BuildContext context, String cat) {
    switch (cat) {
      case 'trip':
        return ('🚗', context.accent);
      case 'subscription':
        return ('💳', context.amber);
      case 'safety':
        return ('🛡️', context.red);
      case 'support':
        return ('💬', context.blue);
      case 'system':
      default:
        return ('🔔', context.textDim);
    }
  }

  static String _fmtTime(DateTime t) {
    final DateTime local = t.toLocal();
    final Duration d = DateTime.now().difference(local);
    if (d.inMinutes < 1) return 'now';
    if (d.inHours < 1) return '${d.inMinutes}m';
    if (d.inDays < 1) return '${d.inHours}h';
    if (d.inDays < 7) return '${d.inDays}d';
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }
}
