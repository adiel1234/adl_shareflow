import 'package:flutter/foundation.dart';

enum AppFlavor { dev, staging, prod }

class AppConfig {
  AppConfig._();

  // הסביבה נקבעת בזמן הרצה דרך --dart-define=FLAVOR=dev/staging/prod
  // ברירת מחדל: dev (פיתוח מקומי)
  static const String _envFlavor =
      String.fromEnvironment('FLAVOR', defaultValue: 'dev');

  static AppFlavor get flavor {
    // In release builds without explicit FLAVOR, default to prod
    if (_envFlavor == 'dev' && kReleaseMode) return AppFlavor.prod;
    switch (_envFlavor) {
      case 'staging':
        return AppFlavor.staging;
      case 'prod':
        return AppFlavor.prod;
      default:
        return AppFlavor.dev;
    }
  }

  static String get apiBaseUrl {
    switch (flavor) {
      case AppFlavor.dev:
        return 'http://localhost:5050/api';
      case AppFlavor.staging:
        return 'https://engine-hacking-anywhere.ngrok-free.dev/api';
      case AppFlavor.prod:
        return 'https://adlshareflow-production.up.railway.app/api';
    }
  }

  static String get appName => 'ADL ShareFlow';
  /// Deprecated — use package_info / ProfileScreen version. Do not hardcode.
  @Deprecated('Use PackageInfo.fromPlatform()')
  static String get appVersion => '1.0.9';

  /// מספר build לתצוגה — תואם `pubspec` (+N), לא `versionCode` גולמי של Android.
  /// APK split-per-abi: Flutter מקודד ABI ב-prefix (arm64 → 2×1000+N).
  static String displayBuildNumber(String raw) {
    final n = int.tryParse(raw);
    if (n == null || n < 1000) return raw;
    final abiPrefix = n ~/ 1000;
    final base = n % 1000;
    if (base > 0 && {1, 2, 4}.contains(abiPrefix)) return '$base';
    return raw;
  }

  static bool get isDev => flavor == AppFlavor.dev;
  static bool get isStaging => flavor == AppFlavor.staging;
  static bool get isProd => flavor == AppFlavor.prod;
}
