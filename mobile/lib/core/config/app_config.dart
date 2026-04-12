enum AppFlavor { dev, staging, prod }

class AppConfig {
  AppConfig._();

  static AppFlavor _flavor = AppFlavor.dev;
  static AppFlavor get flavor => _flavor;

  static void setFlavor(AppFlavor flavor) {
    _flavor = flavor;
  }

  static String get apiBaseUrl {
    switch (_flavor) {
      case AppFlavor.dev:
        return 'http://localhost:5050/api';
      case AppFlavor.staging:
        return 'http://192.168.68.150:5050/api';
      case AppFlavor.prod:
        return 'https://api.shareflow.adl.co.il/api';
    }
  }

  static String get appName => 'ADL ShareFlow';
  static String get appVersion => '1.0.0';

  static bool get isDev => _flavor == AppFlavor.dev;
  static bool get isStaging => _flavor == AppFlavor.staging;
  static bool get isProd => _flavor == AppFlavor.prod;
}
