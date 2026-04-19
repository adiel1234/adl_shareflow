import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/router.dart';
import 'providers/deep_link_provider.dart';
import 'services/feedback_service.dart';
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
  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      AppLinks().uriLinkStream.listen((uri) {
        final code = _parseInviteCode(uri);
        if (code != null) {
          ref.read(pendingInviteCodeProvider.notifier).state = code;
        }
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
