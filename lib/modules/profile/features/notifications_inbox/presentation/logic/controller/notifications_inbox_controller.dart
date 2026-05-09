import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/data/notification_repository.dart';
import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:drivio_driver/modules/commons/types/notification_item.dart';

class NotificationsInboxState {
  const NotificationsInboxState({
    this.items = const <NotificationItem>[],
    this.isLoading = false,
    this.error,
  });

  final List<NotificationItem> items;
  final bool isLoading;
  final String? error;

  int get unreadCount => items.where((NotificationItem n) => n.isUnread).length;

  NotificationsInboxState copyWith({
    List<NotificationItem>? items,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return NotificationsInboxState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class NotificationsInboxController
    extends StateNotifier<NotificationsInboxState> {
  NotificationsInboxController(this._repo)
      : super(const NotificationsInboxState()) {
    _start();
  }

  final NotificationRepository _repo;
  StreamSubscription<NotificationItem>? _insertSub;
  StreamSubscription<NotificationItem>? _updateSub;

  Future<void> _start() async {
    await refresh();
    _insertSub = _repo.watchInserts().listen(_onInsert);
    _updateSub = _repo.watchUpdates().listen(_onUpdate);
  }

  void _onInsert(NotificationItem n) {
    if (!mounted) return;
    if (state.items.any((NotificationItem x) => x.id == n.id)) return;
    state = state.copyWith(items: <NotificationItem>[n, ...state.items]);
  }

  void _onUpdate(NotificationItem n) {
    if (!mounted) return;
    final List<NotificationItem> next = state.items
        .map((NotificationItem x) => x.id == n.id ? n : x)
        .toList(growable: false);
    state = state.copyWith(items: next);
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final List<NotificationItem> rows = await _repo.listMine();
      if (!mounted) return;
      state = state.copyWith(items: rows, isLoading: false);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: "Couldn't load notifications. Pull down to retry.",
      );
    }
  }

  Future<void> markRead(NotificationItem item) async {
    if (!item.isUnread) return;
    // Optimistic update — the realtime UPDATE event will reconfirm.
    final List<NotificationItem> next = state.items
        .map((NotificationItem x) => x.id == item.id
            ? NotificationItem(
                id: x.id,
                userId: x.userId,
                category: x.category,
                title: x.title,
                body: x.body,
                data: x.data,
                readAt: DateTime.now(),
                createdAt: x.createdAt,
              )
            : x)
        .toList(growable: false);
    state = state.copyWith(items: next);
    try {
      await _repo.markRead(item.id);
    } catch (_) {/* best effort; realtime will refresh */}
  }

  Future<void> markAllRead() async {
    if (state.unreadCount == 0) return;
    final DateTime now = DateTime.now();
    final List<NotificationItem> next = state.items
        .map((NotificationItem x) => x.isUnread
            ? NotificationItem(
                id: x.id,
                userId: x.userId,
                category: x.category,
                title: x.title,
                body: x.body,
                data: x.data,
                readAt: now,
                createdAt: x.createdAt,
              )
            : x)
        .toList(growable: false);
    state = state.copyWith(items: next);
    try {
      await _repo.markAllRead();
    } catch (_) {/* best effort */}
  }

  @override
  void dispose() {
    _insertSub?.cancel();
    _updateSub?.cancel();
    super.dispose();
  }
}

final StateNotifierProvider<NotificationsInboxController,
        NotificationsInboxState> notificationsInboxControllerProvider =
    StateNotifierProvider<NotificationsInboxController,
        NotificationsInboxState>(
  (Ref _) =>
      NotificationsInboxController(locator<NotificationRepository>()),
);
