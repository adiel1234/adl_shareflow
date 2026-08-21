import 'dart:io';

import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Syncs the home-screen app icon badge with real unread notification count.
class AppBadgeService {
  AppBadgeService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> sync(int unreadCount) async {
    final count = unreadCount < 0 ? 0 : unreadCount;
    try {
      // Primary path on iOS: UNUserNotificationCenter.setBadgeCount via plugin.
      if (await AppBadgePlus.isSupported()) {
        await AppBadgePlus.updateBadge(count);
      }

      if (count == 0) {
        // Clear tray leftovers that some iOS versions keep counting toward badge.
        await _plugin.cancelAll();
      } else if (Platform.isIOS) {
        // Reinforce badge via a silent local notification (no alert).
        await _plugin.show(
          99001,
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
        await _plugin.cancel(99001);
      }
    } catch (e) {
      debugPrint('[Badge] sync($count) failed: $e');
    }
  }

  static Future<void> clear() => sync(0);
}
