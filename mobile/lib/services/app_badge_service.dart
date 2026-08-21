import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Syncs the home-screen app icon badge with real unread notification count.
/// Never leaves a stale "1" when there is nothing unread.
class AppBadgeService {
  AppBadgeService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const int _badgeSyncId = 99001;

  static Future<void> sync(int unreadCount) async {
    final count = unreadCount < 0 ? 0 : unreadCount;
    try {
      if (Platform.isIOS) {
        await _plugin.show(
          _badgeSyncId,
          null,
          null,
          NotificationDetails(
            iOS: DarwinNotificationDetails(
              presentAlert: false,
              presentBadge: true,
              presentSound: false,
              badgeNumber: count,
            ),
          ),
        );
        await _plugin.cancel(_badgeSyncId);
      } else if (Platform.isAndroid) {
        // Most Android launchers ignore badge APIs; cancel any leftover.
        if (count == 0) {
          await _plugin.cancel(_badgeSyncId);
        }
      }
    } catch (e) {
      debugPrint('[Badge] sync($count) failed: $e');
    }
  }

  static Future<void> clear() => sync(0);
}
