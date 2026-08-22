/// Currency display helpers: symbol, flag, country/name labels.
library;

String currencySymbol(String code) {
  const symbols = {
    'ILS': '₪',
    'USD': '\$',
    'EUR': '€',
    'GBP': '£',
    'JPY': '¥',
    'AUD': 'A\$',
    'CAD': 'C\$',
    'CHF': 'Fr',
    'AED': 'د.إ',
  };
  return symbols[code.toUpperCase()] ?? code.toUpperCase();
}

/// Flag emoji for a supported ISO currency code.
String currencyFlag(String code) {
  const flags = {
    'ILS': '🇮🇱',
    'USD': '🇺🇸',
    'EUR': '🇪🇺',
    'GBP': '🇬🇧',
    'JPY': '🇯🇵',
    'AED': '🇦🇪',
    'CHF': '🇨🇭',
    'CAD': '🇨🇦',
    'AUD': '🇦🇺',
  };
  return flags[code.toUpperCase()] ?? '💱';
}

/// Country / region for the currency (Hebrew or English).
String currencyCountry(String code, {required bool hebrew}) {
  const he = {
    'ILS': 'ישראל',
    'USD': 'ארה״ב',
    'EUR': 'אירופה',
    'GBP': 'בריטניה',
    'JPY': 'יפן',
    'AED': 'איחוד האמירויות',
    'CHF': 'שווייץ',
    'CAD': 'קנדה',
    'AUD': 'אוסטרליה',
  };
  const en = {
    'ILS': 'Israel',
    'USD': 'United States',
    'EUR': 'Eurozone',
    'GBP': 'United Kingdom',
    'JPY': 'Japan',
    'AED': 'UAE',
    'CHF': 'Switzerland',
    'CAD': 'Canada',
    'AUD': 'Australia',
  };
  final key = code.toUpperCase();
  return (hebrew ? he : en)[key] ?? key;
}

/// Short currency name (Hebrew or English).
String currencyName(String code, {required bool hebrew}) {
  const he = {
    'ILS': 'שקל',
    'USD': 'דולר',
    'EUR': 'אירו',
    'GBP': 'לירה שטרלינג',
    'JPY': 'ין',
    'AED': 'דירהם',
    'CHF': 'פרנק',
    'CAD': 'דולר קנדי',
    'AUD': 'דולר אוסטרלי',
  };
  const en = {
    'ILS': 'Shekel',
    'USD': 'Dollar',
    'EUR': 'Euro',
    'GBP': 'Pound',
    'JPY': 'Yen',
    'AED': 'Dirham',
    'CHF': 'Franc',
    'CAD': 'Canadian Dollar',
    'AUD': 'Australian Dollar',
  };
  final key = code.toUpperCase();
  return (hebrew ? he : en)[key] ?? key;
}

/// Dropdown / picker label: flag + country · name (CODE).
String currencyPickerLabel(String code, {required bool hebrew}) {
  final c = code.toUpperCase();
  return '${currencyFlag(c)} ${currencyCountry(c, hebrew: hebrew)} · '
      '${currencyName(c, hebrew: hebrew)} ($c)';
}

/// Formats money with currency symbol, keeping agorot (2 decimal places).
/// Whole amounts render without trailing `.00` for readability.
String formatAmountWithCurrency(num amount, String currencyCode) {
  final d = amount.toDouble();
  final String number;
  if (d == d.roundToDouble()) {
    number = d.round().toString();
  } else {
    number = d.toStringAsFixed(2);
  }
  final symbol = currencySymbol(currencyCode);
  return '$number $symbol';
}
