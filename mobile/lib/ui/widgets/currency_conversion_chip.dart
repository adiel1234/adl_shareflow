import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/currency_provider.dart';
import '../../theme/app_colors.dart';
import '../../l10n/app_localizations.dart';

/// מציג המרת מטבע בזמן אמת בטופס הוצאה
/// מופיע רק כשהמטבע שונה ממטבע הבסיס של הקבוצה
class CurrencyConversionChip extends ConsumerWidget {
  final String fromCurrency;
  final String toCurrency;
  final double amount;

  const CurrencyConversionChip({
    super.key,
    required this.fromCurrency,
    required this.toCurrency,
    required this.amount,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (fromCurrency == toCurrency || amount <= 0) return const SizedBox.shrink();

    final convAsync = ref.watch(conversionProvider(
      conversionParams(from: fromCurrency, to: toCurrency, amount: amount),
    ));

    final l = AppLocalizations.of(context)!;
    return convAsync.when(
      loading: () => _chip(
        icon: Icons.sync,
        text: l.calculating,
        color: AppColors.textSecondary,
        spinning: true,
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (conv) => _chip(
        icon: Icons.currency_exchange,
        text:
            '≈ ${_fmt(conv.convertedAmount)} $toCurrency  (${l.exchangeRateLabel} ${_fmtRate(conv.rate)})',
        color: AppColors.secondary,
      ),
    );
  }

  Widget _chip({
    required IconData icon,
    required String text,
    required Color color,
    bool spinning = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          spinning
              ? SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                )
              : Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(double v) =>
      v >= 100 ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  String _fmtRate(double r) =>
      r >= 1 ? r.toStringAsFixed(2) : r.toStringAsFixed(4);
}
