import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/constants/app_constants.dart';
import '../core/network/api_client.dart';
import '../core/storage/secure_storage.dart';
import 'feedback_service.dart';

/// Background message handler — must be top-level function.
/// Called for data messages (and some Android cases). When the server sends a
/// proper `notification` + APNs `alert`, iOS/Android system trays show the
/// banner without this handler — this is a fallback for data-only delivery.
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] Background message: ${message.messageId}');
  try {
    final data = message.data;
    final title = data['title'] as String? ?? message.notification?.title ?? '';
    final body = data['body'] as String? ?? message.notification?.body ?? '';
    // System already displayed a tray notification — avoid duplicates.
    if (message.notification != null) return;
    if (title.isEmpty && body.isEmpty) return;

    const channel = AndroidNotificationChannel(
      'shareflow_default',
      'ADL ShareFlow',
      description: 'ADL ShareFlow notifications',
      importance: Importance.high,
      playSound: true,
    );
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    await plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    await plugin.show(
      message.messageId?.hashCode ?? title.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
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
    );
  } catch (e) {
    debugPrint('[FCM] Background handler error: $e');
  }
}

class NotificationTapInfo {
  final String title;
  final String body;
  final String? groupId;
  final String? settlementId;
  final String type;

  const NotificationTapInfo({
    required this.title,
    required this.body,
    this.groupId,
    this.settlementId,
    this.type = '',
  });
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
    playSound: true,
  );

  /// Called once from main(), after Firebase.initializeApp().
  Future<void> initialize() async {
    // Register background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

    // Init local notifications (needed for foreground on Android + all iOS)
    await _initLocalNotifications();

    // Request permission (iOS / macOS)
    await _requestPermission();

    // Token registration is deferred until after login (registerToken) or
    // when restoring an existing session — avoids 401 loops on the login screen.
    _messaging.onTokenRefresh.listen((token) async {
      final access =
          await AppSecureStorage.read(AppConstants.accessTokenKey);
      if (access != null) await _sendTokenToBackend(token);
    });

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
      // On iOS, FCM token may be null until APNs token is available.
      if (!kIsWeb && Platform.isIOS) {
        String? apns = await _messaging.getAPNSToken();
        for (var i = 0; i < 10 && apns == null; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          apns = await _messaging.getAPNSToken();
        }
        if (apns == null) {
          debugPrint('[FCM] APNs token not ready yet — will retry on refresh');
        }
      }
      final token = await _messaging.getToken();
      if (token != null) await _sendTokenToBackend(token);
    } catch (e) {
      debugPrint('[FCM] Failed to get token: $e');
    }
  }

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
    final info = _tapInfoFromMessage(message);
    FeedbackService.notification();

    // Always show local notification (iOS may omit message.notification in foreground).
    if (info.title.isNotEmpty || info.body.isNotEmpty) {
      _localNotifications.show(
        message.messageId?.hashCode ?? info.title.hashCode,
        info.title,
        info.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _androidChannel.id,
            _androidChannel.name,
            channelDescription: _androidChannel.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            playSound: true,
            enableVibration: true,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            sound: 'default',
          ),
        ),
        payload: _payloadFromInfo(info),
      );
    }

    // Trigger data refresh for data-changing events
    if (info.groupId != null && info.groupId!.isNotEmpty) {
      _onDataChanged?.call(info.groupId!, info.type);
    }

    // Creditor must act immediately — open in-app dialog with confirm action.
    if (info.type == 'settlement_requested') {
      _onNotificationOpened?.call(info);
    }
  }

  void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    final info = _infoFromPayload(payload);
    if (info != null) _onNotificationOpened?.call(info);
  }

  /// Set callback for when user taps a notification (foreground local or FCM).
  void setNotificationTapCallback(void Function(NotificationTapInfo info) callback) {
    _onNotificationOpened = callback;
  }

  /// Setup tap handler for notifications that opened the app from terminated
  /// or background state. Call after setNotificationTapCallback().
  Future<void> setupOpenedAppHandler() async {
    // Terminated state — app was opened by tapping the notification
    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      _onNotificationOpened?.call(_tapInfoFromMessage(initial));
    }

    // Background state — app was resumed by tapping the notification
    FirebaseMessaging.onMessageOpenedApp.listen(
      (msg) => _onNotificationOpened?.call(_tapInfoFromMessage(msg)),
    );
  }

  void Function(NotificationTapInfo info)? _onNotificationOpened;

  /// Called when a foreground notification arrives — allows the UI to refresh data.
  void Function(String groupId, String notificationType)? _onDataChanged;

  /// Set callback to refresh Riverpod providers when data changes in foreground.
  void setDataChangeCallback(
      void Function(String groupId, String notificationType) callback) {
    _onDataChanged = callback;
  }

  NotificationTapInfo _tapInfoFromMessage(RemoteMessage message) {
    final data = message.data;
    final notification = message.notification;
    // Prefer data payload — notification.body may be truncated by the OS.
    return NotificationTapInfo(
      title: data['title'] as String? ?? notification?.title ?? '',
      body: data['body'] as String? ?? notification?.body ?? '',
      groupId: data['group_id'] as String?,
      settlementId: data['settlement_id'] as String?,
      type: data['type'] as String? ?? '',
    );
  }

  String _payloadFromInfo(NotificationTapInfo info) {
    return jsonEncode({
      'title': info.title,
      'body': info.body,
      if (info.groupId != null) 'group_id': info.groupId,
      if (info.settlementId != null) 'settlement_id': info.settlementId,
      'type': info.type,
    });
  }

  NotificationTapInfo? _infoFromPayload(String payload) {
    try {
      final map = jsonDecode(payload) as Map<String, dynamic>;
      return NotificationTapInfo(
        title: map['title'] as String? ?? '',
        body: map['body'] as String? ?? '',
        groupId: map['group_id'] as String?,
        settlementId: map['settlement_id'] as String?,
        type: map['type'] as String? ?? '',
      );
    } catch (_) {
      // Legacy payload: "group_id:<id>"
      if (payload.startsWith('group_id:')) {
        return NotificationTapInfo(
          title: '',
          body: '',
          groupId: payload.substring('group_id:'.length),
        );
      }
      return null;
    }
  }
}
