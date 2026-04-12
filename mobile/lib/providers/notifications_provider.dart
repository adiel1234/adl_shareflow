import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/notifications/data/notifications_repository.dart';
import '../features/notifications/domain/notification_model.dart';

final notificationsRepositoryProvider =
    Provider((_) => NotificationsRepository());

class NotificationsState {
  final List<AppNotification> items;
  final int unreadCount;
  final bool isLoading;
  final String? error;

  const NotificationsState({
    this.items = const [],
    this.unreadCount = 0,
    this.isLoading = false,
    this.error,
  });

  NotificationsState copyWith({
    List<AppNotification>? items,
    int? unreadCount,
    bool? isLoading,
    String? error,
  }) =>
      NotificationsState(
        items: items ?? this.items,
        unreadCount: unreadCount ?? this.unreadCount,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class NotificationsNotifier extends StateNotifier<NotificationsState> {
  final NotificationsRepository _repo;

  NotificationsNotifier(this._repo) : super(const NotificationsState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _repo.getNotifications();
      state = state.copyWith(
        items: result.items,
        unreadCount: result.unreadCount,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> markRead(String id) async {
    try {
      await _repo.markRead(id);
      state = state.copyWith(
        items: state.items
            .map((n) => n.id == id ? n.copyWith(isRead: true) : n)
            .toList(),
        unreadCount: (state.unreadCount - 1).clamp(0, 9999),
      );
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    try {
      await _repo.markAllRead();
      state = state.copyWith(
        items: state.items.map((n) => n.copyWith(isRead: true)).toList(),
        unreadCount: 0,
      );
    } catch (_) {}
  }
}

final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, NotificationsState>(
  (ref) => NotificationsNotifier(ref.watch(notificationsRepositoryProvider)),
);

// Simple unread count provider used by bottom nav badge
final unreadCountProvider = Provider<int>((ref) {
  return ref.watch(notificationsProvider).unreadCount;
});
