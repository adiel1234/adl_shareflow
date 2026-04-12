import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/currency/data/currency_repository.dart';

final currencyRepositoryProvider = Provider((_) => CurrencyRepository());

final exchangeRatesProvider =
    FutureProvider.family<List<ExchangeRate>, String>((ref, baseCurrency) {
  return ref.watch(currencyRepositoryProvider).getRates(baseCurrency);
});

final conversionProvider = FutureProvider.family<ConversionResult, _ConversionParams>(
  (ref, params) => ref
      .watch(currencyRepositoryProvider)
      .convert(from: params.from, to: params.to, amount: params.amount),
);

class _ConversionParams {
  final String from;
  final String to;
  final double amount;

  const _ConversionParams({
    required this.from,
    required this.to,
    required this.amount,
  });

  @override
  bool operator ==(Object other) =>
      other is _ConversionParams &&
      from == other.from &&
      to == other.to &&
      amount == other.amount;

  @override
  int get hashCode => Object.hash(from, to, amount);
}

// Helper to create conversion params
_ConversionParams conversionParams({
  required String from,
  required String to,
  required double amount,
}) =>
    _ConversionParams(from: from, to: to, amount: amount);
