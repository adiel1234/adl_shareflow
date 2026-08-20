/// Display helpers for money amounts in UI and share messages.
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
  };
  return symbols[code.toUpperCase()] ?? code.toUpperCase();
}

/// Formats money with currency symbol, keeping agorot (2 decimal places).
/// Whole amounts render without trailing `.00` for readability.
/// e.g. `149.5 ₪`, `33.33 ₪`, `20 $` — never bare `ILS`, never silent round to int.
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
