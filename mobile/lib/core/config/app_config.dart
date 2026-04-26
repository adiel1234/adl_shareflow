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
  static String get appVersion => '1.0.1';

  static bool get isDev => flavor == AppFlavor.dev;
  static bool get isStaging => flavor == AppFlavor.staging;
  static bool get isProd => flavor == AppFlavor.prod;
}
