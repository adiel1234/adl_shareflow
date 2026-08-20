import 'package:app_links/app_links.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_config.dart';
import 'core/config/router.dart';
import 'core/network/api_client.dart';
import 'providers/auth_provider.dart';
import 'providers/balances_provider.dart';
import 'providers/deep_link_provider.dart';
import 'providers/expenses_provider.dart';
import 'providers/notifications_provider.dart';
import 'features/balances/data/balance_repository.dart';
import 'features/notifications/presentation/widgets/notification_detail_dialog.dart';
import 'services/feedback_service.dart';
import 'services/fcm_service.dart';
import 'theme/app_theme.dart';
import 'providers/locale_provider.dart';
import 'l10n/app_localizations.dart';

/// Parses an invite code from a shareflow:// or https:// deep link URI.
/// shareflow://join/ABC123  → host="join", pathSegments=["ABC123"]
/// https://host/join/ABC123 → pathSegments=["join","ABC123"]
String? _parseInviteCode(Uri uri) {
  if (uri.scheme == 'shareflow') {
    if (uri.host == 'join' && uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.first;
    }
    return null;
  }
  if (uri.scheme == 'https' || uri.scheme == 'http') {
    final segs = uri.pathSegments;
    final idx = segs.indexOf('join');
    if (idx >= 0 && idx + 1 < segs.length) return segs[idx + 1];
  }
  return null;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();
  // Must be registered before runApp so background/killed isolates can show
  // data-only fallbacks. System notification+data banners do not need this.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await FeedbackService.init();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  // Capture the initial deep link (app was launched via shareflow://)
  String? initialCode;
  if (!kIsWeb) {
    try {
      final appLinks = AppLinks();
      final initialUri = await appLinks.getInitialLink();
      if (initialUri != null) initialCode = _parseInviteCode(initialUri);
    } catch (_) {}

    // If no deep link, try clipboard-based deferred invite
    // (written by the /join/{code} web page before the user downloads the app)
    if (initialCode == null) {
      try {
        final clipData = await Clipboard.getData('text/plain');
        final text = clipData?.text ?? '';
        const prefix = 'shareflow-invite:';
        if (text.startsWith(prefix)) {
          initialCode = text.substring(prefix.length).trim();
          await Clipboard.setData(const ClipboardData(text: ''));
        }
      } catch (_) {}
    }

    // Fallback: IP-based deferred link from server
    if (initialCode == null) {
      try {
        final dio = Dio(BaseOptions(
          baseUrl: AppConfig.apiBaseUrl,
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ));
        final response = await dio.get('/deferred-link');
        final code = response.data['invite_code'] as String?;
        if (code != null && code.isNotEmpty) initialCode = code;
      } catch (_) {}
    }
  }

  runApp(
    ProviderScope(
      overrides: [
        if (initialCode != null)
          pendingInviteCodeProvider.overrideWith((_) => initialCode),
      ],
      child: const ShareFlowApp(),
    ),
  );
}

class ShareFlowApp extends ConsumerStatefulWidget {
  const ShareFlowApp({super.key});

  @override
  ConsumerState<ShareFlowApp> createState() => _ShareFlowAppState();
}

class _ShareFlowAppState extends ConsumerState<ShareFlowApp>
    with WidgetsBindingObserver {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  bool _isOffline = false;
  bool _fcmStarted = false;
  bool _handlingSessionExpired = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Register API-level callbacks
    ApiClient.onSessionExpired = _handleSessionExpired;
    ApiClient.onServerError = _handleServerError;

    // Offline detection
    Connectivity().onConnectivityChanged.listen((results) {
      final offline = results.every((r) => r == ConnectivityResult.none);
      if (mounted && offline != _isOffline) {
        setState(() => _isOffline = offline);
      }
    });

    if (!kIsWeb) {
      // Deep links
      AppLinks().uriLinkStream.listen((uri) {
        final code = _parseInviteCode(uri);
        if (code != null) {
          ref.read(pendingInviteCodeProvider.notifier).state = code;
        }
      });

      // FCM — set tap callback FIRST (before async initialize),
      // so no notification tap is missed due to race conditions.
      FcmService.instance.setNotificationTapCallback((info) {
        _showNotificationDialog(info);
      });

      // FCM — refresh Riverpod providers when a data-changing notification
      // arrives while the app is in the foreground (e.g. new_expense added by
      // another group member). This avoids a manual pull-to-refresh.
      FcmService.instance.setDataChangeCallback((groupId, type) {
        _invalidateForGroup(groupId, type);
      });

      WidgetsBinding.instance.addPostFrameCallback((_) => _startFcmIfReady());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        !kIsWeb &&
        ref.read(authProvider).isLoggedIn) {
      // Re-register after unlock / permission change / APNs delayed grant.
      FcmService.instance.registerToken();
    }
  }

  /// Start FCM only after auth init finishes — avoids concurrent secure-storage
  /// reads on Android (auth + API interceptor) that can deadlock at startup.
  void _startFcmIfReady() {
    if (_fcmStarted || kIsWeb) return;
    if (ref.read(authProvider).isLoading) return;
    _fcmStarted = true;

    FcmService.instance.initialize().then((_) {
      FcmService.instance.setupOpenedAppHandler();
      if (ref.read(authProvider).isLoggedIn) {
        FcmService.instance.registerToken();
      }
    });
  }

  /// Invalidate relevant Riverpod providers when a push notification signals
  /// that data changed in a group (e.g. new expense, settlement confirmed).
  void _invalidateForGroup(String groupId, String type) {
    switch (type) {
      case 'new_expense':
        ref.invalidate(expensesProvider(groupId));
        ref.invalidate(balancesProvider(groupId));
        break;
      case 'settlement_requested':
      case 'settlement_confirmed':
        ref.invalidate(balancesProvider(groupId));
        ref.invalidate(pendingSettlementsProvider(groupId));
        ref.invalidate(settlementPlanProvider(groupId));
        break;
      case 'group_activated':
      case 'group_expiring_soon':
      case 'tier_upgrade_required':
        // Handled by re-fetching group list on next navigation
        break;
      default:
        ref.invalidate(expensesProvider(groupId));
        ref.invalidate(balancesProvider(groupId));
    }
    ref.read(notificationsProvider.notifier).load();
  }

  void _handleSessionExpired() {
    if (_handlingSessionExpired) return;
    _handlingSessionExpired = true;

    ref.read(authProvider.notifier).logout();
    _navigatorKey.currentState?.pushNamedAndRemoveUntil(
      '/login',
      (_) => false,
    );
    _messengerKey.currentState?.showSnackBar(
      const SnackBar(
        content: Text(
            'החיבור הסתיים. ניתן להשלים התחברות עם הפרטים השמורים.'),
        duration: Duration(seconds: 4),
      ),
    );

    Future.delayed(const Duration(seconds: 3), () {
      _handlingSessionExpired = false;
    });
  }

  Future<void> _showNotificationDialog(NotificationTapInfo info) async {
    final nav = _navigatorKey.currentState;
    if (nav == null || !nav.mounted) return;
    final ctx = nav.context;
    if (!ctx.mounted) return;

    final body = await resolveNotificationBodyForPushTap(
      type: info.type,
      body: info.body,
      groupId: info.groupId,
    );

    if (!ctx.mounted) return;

    final settlementId = info.settlementId;
    final groupId = info.groupId;

    showNotificationDetailDialog(
      ctx,
      title: info.title,
      body: body,
      type: info.type.isNotEmpty ? info.type : null,
      groupId: groupId,
      settlementId: settlementId,
      onConfirmSettlement: settlementId != null && settlementId.isNotEmpty
          ? () => _confirmSettlementFromNotification(settlementId, groupId)
          : null,
      onGoToGroup: groupId != null && groupId.isNotEmpty
          ? () => _openGroupBalances(groupId)
          : null,
    );
  }

  Future<bool> _confirmSettlementFromNotification(
    String settlementId,
    String? groupId,
  ) async {
    try {
      await BalanceRepository().approveSettlement(settlementId);
      if (groupId != null && groupId.isNotEmpty) {
        ref.invalidate(balancesProvider(groupId));
        ref.invalidate(pendingSettlementsProvider(groupId));
        ref.invalidate(settlementPlanProvider(groupId));
        ref.invalidate(expensesProvider(groupId));
      }
      ref.read(notificationsProvider.notifier).load();
      _messengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('תשלום אושר בהצלחה ✓')),
      );
      return true;
    } catch (e) {
      String msg = 'שגיאה באישור התשלום';
      if (e is DioException) {
        msg = (e.response?.data?['message'] as String?) ?? msg;
      }
      _messengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700),
      );
      return false;
    }
  }

  void _openGroupBalances(String groupId) {
    _navigatorKey.currentState?.pushNamed(
      '/group-detail',
      arguments: {'groupId': groupId, 'initialTab': 1},
    );
  }

  void _handleServerError(String message) {
    _messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (_, next) {
      if (!next.isLoading) _startFcmIfReady();
    });

    final locale = ref.watch(localeProvider);
    final isHe = locale.languageCode == 'he';
    return MaterialApp(
      title: 'ADL ShareFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _messengerKey,
      onGenerateRoute: AppRouter.onGenerateRoute,
      initialRoute: '/',
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('he'),
        Locale('en'),
      ],
      locale: locale,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(
              MediaQuery.of(context).textScaler.scale(1.0).clamp(0.85, 1.3),
            ),
          ),
          child: Directionality(
            textDirection: isHe ? TextDirection.rtl : TextDirection.ltr,
            child: Column(
              children: [
                if (_isOffline)
                  Material(
                    color: Colors.grey.shade800,
                    child: SafeArea(
                      bottom: false,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.wifi_off, color: Colors.white, size: 16),
                            SizedBox(width: 8),
                            Text(
                              'אין חיבור לאינטרנט',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                Expanded(child: child!),
              ],
            ),
          ),
        );
      },
    );
  }
}
