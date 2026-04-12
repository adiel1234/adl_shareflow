class AppConstants {
  AppConstants._();

  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userKey = 'current_user';

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
