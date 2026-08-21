import '../domain/notification_model.dart';
import '../../../core/network/api_client.dart';

class NotificationsRepository {
  final ApiClient _api = ApiClient.instance;

  Future<({List<AppNotification> items, int unreadCount})> getNotifications({
    int page = 1,
  }) async {
    // Walk every page — same pattern as expenses, so the list is never capped
    // at the first ~30 items.
    const perPage = 100;
    const maxPages = 50;
    final all = <AppNotification>[];
    var currentPage = page;
    var unreadCount = 0;
    var reportedTotal = -1;

    for (var i = 0; i < maxPages; i++) {
      final response = await _api.get(
        '/notifications',
        params: {'page': currentPage, 'per_page': perPage},
      );
      final data = response.data['data'] as Map<String, dynamic>;
      final list = (data['notifications'] as List? ?? const [])
          .map((n) => AppNotification.fromJson(n as Map<String, dynamic>))
          .toList();
      all.addAll(list);
      unreadCount = data['unread_count'] as int? ?? unreadCount;
      final pagination = data['pagination'] as Map<String, dynamic>?;
      reportedTotal = (pagination?['total'] as num?)?.toInt() ?? all.length;
      if (all.length >= reportedTotal || list.length < perPage) break;
      currentPage++;
    }

    return (items: all, unreadCount: unreadCount);
  }

  Future<void> markRead(String notificationId) async {
    await _api.put('/notifications/$notificationId/read');
  }

  Future<void> markAllRead() async {
    await _api.put('/notifications/read-all');
  }

  Future<void> registerFcmToken(String token, String platform) async {
    await _api.post('/notifications/fcm-token',
        data: {'token': token, 'platform': platform});
  }

  Future<void> unregisterFcmToken(String token) async {
    await _api.delete('/notifications/fcm-token', data: {'token': token});
  }
}
