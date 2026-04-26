import '../domain/notification_model.dart';
import '../../../core/network/api_client.dart';

class NotificationsRepository {
  final ApiClient _api = ApiClient.instance;

  Future<({List<AppNotification> items, int unreadCount})> getNotifications({
    int page = 1,
  }) async {
    final response = await _api.get('/notifications', params: {'page': page});
    final data = response.data['data'] as Map<String, dynamic>;
    final items = (data['notifications'] as List)
        .map((n) => AppNotification.fromJson(n as Map<String, dynamic>))
        .toList();
    return (items: items, unreadCount: data['unread_count'] as int? ?? 0);
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
