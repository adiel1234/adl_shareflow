import 'package:app_links/app_links.dart';
import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_config.dart';
import 'core/config/router.dart';
import 'providers/deep_link_provider.dart';
import 'services/feedback_service.dart';
import 'services/fcm_service.dart';
import 'theme/app_theme.dart';
import 'providers/locale_provider.dart';
import 'l10n/app_localizations.dart';

/// Parses an invite code from a shareflow:// deep link URI.
/// Returns null if the URI is not a valid join link.
String? _parseInviteCode(Uri uri) {
  if (uri.scheme != 'shareflow') return null;
  final segments = uri.pathSegments;
  if (segments.length >= 2 && segments[0] == 'join') return segments[1];
  return null;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();
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

class _ShareFlowAppState extends ConsumerState<ShareFlowApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();

    if (!kIsWeb) {
      // Deep links
      AppLinks().uriLinkStream.listen((uri) {
        final code = _parseInviteCode(uri);
        if (code != null) {
          ref.read(pendingInviteCodeProvider.notifier).state = code;
        }
      });

      // FCM — request permission + register token, then set up tap navigation
      FcmService.instance.initialize().then((_) {
        FcmService.instance.setupOpenedAppHandler((groupId) {
          _navigatorKey.currentState?.pushNamed(
            '/group-detail',
            arguments: {'groupId': groupId},
          );
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final isHe = locale.languageCode == 'he';
    return MaterialApp(
      title: 'ADL ShareFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      navigatorKey: _navigatorKey,
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
            child: child!,
          ),
        );
      },
    );
  }
}
