import '../../../core/network/api_client.dart';

class ExchangeRate {
  final String fromCurrency;
  final String toCurrency;
  final double rate;
  final String source;

  const ExchangeRate({
    required this.fromCurrency,
    required this.toCurrency,
    required this.rate,
    required this.source,
  });

  factory ExchangeRate.fromJson(Map<String, dynamic> json) => ExchangeRate(
        fromCurrency: json['from_currency'] as String,
        toCurrency: json['to_currency'] as String,
        rate: double.parse(json['rate'] as String),
        source: json['source'] as String? ?? 'unknown',
      );
}

class ConversionResult {
  final String fromCurrency;
  final String toCurrency;
  final double originalAmount;
  final double convertedAmount;
  final double rate;

  const ConversionResult({
    required this.fromCurrency,
    required this.toCurrency,
    required this.originalAmount,
    required this.convertedAmount,
    required this.rate,
  });

  factory ConversionResult.fromJson(Map<String, dynamic> json) =>
      ConversionResult(
        fromCurrency: json['from_currency'] as String,
        toCurrency: json['to_currency'] as String,
        originalAmount: double.parse(json['original_amount'] as String),
        convertedAmount: double.parse(json['converted_amount'] as String),
        rate: double.parse(json['rate'] as String),
      );
}

class CurrencyRepository {
  final ApiClient _api = ApiClient.instance;

  Future<List<ExchangeRate>> getRates(String baseCurrency) async {
    final response = await _api.get(
      '/currency/rates',
      params: {'from': baseCurrency},
    );
    final rates = (response.data['data']['rates'] as List)
        .map((r) => ExchangeRate.fromJson(r as Map<String, dynamic>))
        .toList();
    return rates;
  }

  Future<ConversionResult> convert({
    required String from,
    required String to,
    required double amount,
  }) async {
    final response = await _api.get('/currency/convert', params: {
      'from': from,
      'to': to,
      'amount': amount.toString(),
    });
    return ConversionResult.fromJson(
        response.data['data'] as Map<String, dynamic>);
  }
}
