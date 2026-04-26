import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/network/api_client.dart';

/// Background message handler — must be top-level function.
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  // Firebase is already initialized when this is called.
  // No UI work here — just log / store if needed.
  debugPrint('[FCM] Background message: ${message.messageId}');
}

class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  final _messaging = FirebaseMessaging.instance;

  final _localNotifications = FlutterLocalNotificationsPlugin();

  /// Channel used for foreground notifications on Android.
  static const _androidChannel = AndroidNotificationChannel(
    'shareflow_default',
    'ADL ShareFlow',
    description: 'ADL ShareFlow notifications',
    importance: Importance.high,
  );

  /// Called once from main(), after Firebase.initializeApp().
  Future<void> initialize() async {
    // Register background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

    // Init local notifications (needed for foreground on Android + all iOS)
    await _initLocalNotifications();

    // Request permission (iOS / macOS)
    await _requestPermission();

    // Get token and send to backend
    await _registerToken();

    // Listen for token refresh
    _messaging.onTokenRefresh.listen(_sendTokenToBackend);

    // Foreground message display
    FirebaseMessaging.onMessage.listen(_handleForeground);
  }

  /// Request notification permission on iOS.
  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('[FCM] Permission: ${settings.authorizationStatus}');
  }

  /// Get the FCM token and register it with our backend.
  /// Call this after login to ensure the token is registered when auth is ready.
  Future<void> registerToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) await _sendTokenToBackend(token);
    } catch (e) {
      debugPrint('[FCM] Failed to get token: $e');
    }
  }

  Future<void> _registerToken() => registerToken();

  Future<void> _sendTokenToBackend(String token) async {
    try {
      final platform = Platform.isAndroid ? 'android' : 'ios';
      await ApiClient.instance.post('/notifications/fcm-token', data: {
        'token': token,
        'platform': platform,
      });
      debugPrint('[FCM] Token registered with backend');
    } catch (e) {
      debugPrint('[FCM] Failed to register token: $e');
    }
  }

  /// Remove token from backend (call on logout).
  Future<void> unregisterToken() async {
    try {
      final token = await _messaging.getToken();
      if (token == null) return;
      await ApiClient.instance.delete('/notifications/fcm-token',
          data: {'token': token});
      await _messaging.deleteToken();
      debugPrint('[FCM] Token unregistered');
    } catch (e) {
      debugPrint('[FCM] Failed to unregister token: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Local notifications setup
  // ---------------------------------------------------------------------------

  Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create Android channel
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);

    // On iOS, tell FCM to show foreground notifications via local plugin
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  // ---------------------------------------------------------------------------
  // Message handlers
  // ---------------------------------------------------------------------------

  void _handleForeground(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: _payloadFromData(message.data),
    );
  }

  void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    _navigateFromPayload(payload);
  }

  /// Setup tap handler for notifications that opened the app from terminated
  /// or background state.
  Future<void> setupOpenedAppHandler(
      void Function(String groupId) navigateToGroup) async {
    _navigateToGroup = navigateToGroup;

    // Terminated state — app was opened by tapping the notification
    final initial = await _messaging.getInitialMessage();
    if (initial != null) _handleNotificationTap(initial.data);

    // Background state — app was resumed by tapping the notification
    FirebaseMessaging.onMessageOpenedApp.listen(
      (msg) => _handleNotificationTap(msg.data),
    );
  }

  void Function(String groupId)? _navigateToGroup;

  void _handleNotificationTap(Map<String, dynamic> data) {
    final groupId = data['group_id'] as String?;
    if (groupId != null && groupId.isNotEmpty) {
      _navigateToGroup?.call(groupId);
    }
  }

  void _navigateFromPayload(String payload) {
    // payload is "group_id:<id>"
    if (payload.startsWith('group_id:')) {
      final groupId = payload.substring('group_id:'.length);
      _navigateToGroup?.call(groupId);
    }
  }

  String _payloadFromData(Map<String, dynamic> data) {
    final groupId = data['group_id'] as String?;
    if (groupId != null) return 'group_id:$groupId';
    return '';
  }
}
