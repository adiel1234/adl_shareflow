import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/constants/app_constants.dart';
import '../core/network/api_client.dart';
import '../core/storage/secure_storage.dart';
import 'app_badge_service.dart';
import 'feedback_service.dart';

/// Background message handler — must be a top-level function and registered
/// immediately after [Firebase.initializeApp] (before [runApp]).
///
/// When the server sends `notification` + APNs `alert`, iOS/Android system
/// trays show the banner without this handler. This is a fallback for
/// data-only delivery so a killed/background device still gets a tray item.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
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
    final payload = jsonEncode({
      'title': title,
      'body': body,
      if (data['group_id'] != null) 'group_id': data['group_id'],
      if (data['settlement_id'] != null) 'settlement_id': data['settlement_id'],
      'type': data['type'] ?? '',
    });
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
          playSound: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'default',
        ),
      ),
      payload: payload,
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
  final int? badge;

  const NotificationTapInfo({
    required this.title,
    required this.body,
    this.groupId,
    this.settlementId,
    this.type = '',
    this.badge,
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

  bool _initialized = false;
  StreamSubscription<RemoteMessage>? _foregroundSub;

  /// Called once from main() after auth is ready.
  /// Background handler must already be registered in [main] before [runApp].
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Init local notifications (needed for foreground on Android + all iOS)
    await _initLocalNotifications();

    // Request permission (iOS / Android 13+)
    await _requestPermission();

    // Token registration is deferred until after login (registerToken) or
    // when restoring an existing session — avoids 401 loops on the login screen.
    _messaging.onTokenRefresh.listen((token) async {
      final access =
          await AppSecureStorage.read(AppConstants.accessTokenKey);
      if (access != null) await _sendTokenToBackend(token);
    });

    // Foreground message display — single subscription only.
    await _foregroundSub?.cancel();
    _foregroundSub = FirebaseMessaging.onMessage.listen(_handleForeground);
  }

  /// Request notification permission (iOS + Android 13+).
  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('[FCM] Permission: ${settings.authorizationStatus}');

    // Android 13+: explicit runtime POST_NOTIFICATIONS (needed for tray when
    // the app is backgrounded/killed).
    if (!kIsWeb && Platform.isAndroid) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  /// Get the FCM token and register it with our backend.
  /// Call this after login to ensure the token is registered when auth is ready.
  /// Retries when APNs is slow (common on iOS cold start / wireless debug).
  Future<void> registerToken() async {
    try {
      // On iOS, FCM token may be null until APNs token is available.
      if (!kIsWeb && Platform.isIOS) {
        String? apns = await _messaging.getAPNSToken();
        for (var i = 0; i < 30 && apns == null; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          apns = await _messaging.getAPNSToken();
        }
        if (apns == null) {
          debugPrint('[FCM] APNs token not ready after wait; scheduling retries');
          _scheduleRegisterRetries();
          return;
        }
        debugPrint('[FCM] APNs token ready');
      }

      String? token;
      for (var i = 0; i < 5; i++) {
        try {
          token = await _messaging.getToken();
        } catch (e) {
          debugPrint('[FCM] getToken attempt ${i + 1} failed: $e');
        }
        if (token != null) break;
        await Future<void>.delayed(Duration(milliseconds: 400 * (i + 1)));
      }

      if (token != null) {
        await _sendTokenToBackend(token);
      } else {
        debugPrint('[FCM] FCM token still null; scheduling retries');
        _scheduleRegisterRetries();
      }
    } catch (e) {
      debugPrint('[FCM] Failed to get token: $e');
      _scheduleRegisterRetries();
    }
  }

  int _registerRetryAttempt = 0;

  void _scheduleRegisterRetries() {
    if (_registerRetryAttempt >= 5) return;
    _registerRetryAttempt += 1;
    final delay = Duration(seconds: 2 * _registerRetryAttempt);
    Future<void>.delayed(delay, () async {
      final access =
          await AppSecureStorage.read(AppConstants.accessTokenKey);
      if (access == null) return;
      debugPrint('[FCM] Retry registerToken (#$_registerRetryAttempt)');
      await registerToken();
    });
  }

  Future<void> _sendTokenToBackend(String token) async {
    try {
      final platform = Platform.isAndroid ? 'android' : 'ios';
      await ApiClient.instance.post('/notifications/fcm-token', data: {
        'token': token,
        'platform': platform,
      });
      _registerRetryAttempt = 0;
      debugPrint('[FCM] Token registered with backend ($platform)');
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
    // Foreground banners come from local notifications only — avoid double
    // system+local alerts (was causing 2–3 trays per push).
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: true,
      sound: false,
    );
  }

  // ---------------------------------------------------------------------------
  // Message handlers
  // ---------------------------------------------------------------------------

  void _handleForeground(RemoteMessage message) {
    final info = _tapInfoFromMessage(message);

    if (info.badge != null) {
      AppBadgeService.sync(info.badge!);
    }
    // Badge-only sync from server — no sound / banner.
    if (info.type == 'badge_sync') {
      return;
    }

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
            number: info.badge,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            sound: 'default',
            badgeNumber: info.badge,
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
    // Terminated via system FCM notification
    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      _onNotificationOpened?.call(_tapInfoFromMessage(initial));
    }

    // Terminated via local notification (data-only fallback path)
    final launchDetails =
        await _localNotifications.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      final payload = launchDetails!.notificationResponse?.payload;
      if (payload != null && payload.isNotEmpty) {
        final info = _infoFromPayload(payload);
        if (info != null) _onNotificationOpened?.call(info);
      }
    }

    // Background — resumed by tapping a system FCM notification
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
    final badgeRaw = data['badge'];
    final badge = badgeRaw == null ? null : int.tryParse('$badgeRaw');
    // Prefer data payload — notification.body may be truncated by the OS.
    return NotificationTapInfo(
      title: data['title'] as String? ?? notification?.title ?? '',
      body: data['body'] as String? ?? notification?.body ?? '',
      groupId: data['group_id'] as String?,
      settlementId: data['settlement_id'] as String?,
      type: data['type'] as String? ?? '',
      badge: badge,
    );
  }

  String _payloadFromInfo(NotificationTapInfo info) {
    return jsonEncode({
      'title': info.title,
      'body': info.body,
      if (info.groupId != null) 'group_id': info.groupId,
      if (info.settlementId != null) 'settlement_id': info.settlementId,
      'type': info.type,
      if (info.badge != null) 'badge': info.badge,
    });
  }

  NotificationTapInfo? _infoFromPayload(String payload) {
    try {
      final map = jsonDecode(payload) as Map<String, dynamic>;
      final badgeRaw = map['badge'];
      final badge = badgeRaw == null ? null : int.tryParse('$badgeRaw');
      return NotificationTapInfo(
        title: map['title'] as String? ?? '',
        body: map['body'] as String? ?? '',
        groupId: map['group_id'] as String?,
        settlementId: map['settlement_id'] as String?,
        type: map['type'] as String? ?? '',
        badge: badge,
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
