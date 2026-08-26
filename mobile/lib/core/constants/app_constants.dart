class AppConstants {
  AppConstants._();

  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userKey = 'current_user';

  /// Survives logout / session expiry (userfill login with user consent).
  static const String rememberedEmailKey = 'remembered_email';
  static const String rememberedPasswordKey = 'remembered_password';
  static const String rememberMeKey = 'remember_me';
  static const String preferredCurrencyKey = 'preferred_currency';

  /// Firebase Web client ID (oauth client_type 3) for Google Sign-In ID tokens.
  static const String googleServerClientId =
      '703436621794-uijr6vaao78sghtm4g9q5f69limb4hba.apps.googleusercontent.com';

  /// iOS OAuth client ID from GoogleService-Info.plist (also accepted by backend).
  static const String googleIosClientId =
      '703436621794-gmrgkd8sfh64u3l2gm2vh3v3vr78e2lk.apps.googleusercontent.com';

  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 60);

  static const List<String> supportedCurrencies = [
    'ILS', 'USD', 'EUR', 'GBP', 'JPY', 'AED', 'CHF', 'CAD', 'AUD',
  ];

  static const List<String> expenseCategories = [
    'food', 'travel', 'housing', 'transport', 'entertainment',
    'shopping', 'health', 'utilities', 'other',
  ];

  static const List<String> groupCategories = [
    'apartment', 'trip', 'vehicle', 'event', 'other',
  ];
}
