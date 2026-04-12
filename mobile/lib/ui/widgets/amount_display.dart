import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// Large money display widget — the hero element of the app
class AmountDisplay extends StatelessWidget {
  final String amount;
  final String currency;
  final bool isPositive;
  final bool isNegative;
  final double fontSize;

  const AmountDisplay({
    super.key,
    required this.amount,
    required this.currency,
    this.isPositive = false,
    this.isNegative = false,
    this.fontSize = 36,
  });

  Color get _color {
    if (isPositive) return AppColors.positive;
    if (isNegative) return AppColors.negative;
    return AppColors.neutral;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          currency,
          style: TextStyle(
            fontSize: fontSize * 0.5,
            fontWeight: FontWeight.w600,
            color: _color,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          amount,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: _color,
            letterSpacing: -1.0,
          ),
        ),
      ],
    );
  }
}

/// Balance pill — colored badge showing net amount
class BalancePill extends StatelessWidget {
  final String amount;
  final String currency;
  final bool isPositive;

  const BalancePill({
    super.key,
    required this.amount,
    required this.currency,
    required this.isPositive,
  });

  @override
  Widget build(BuildContext context) {
    final color = isPositive ? AppColors.positive : AppColors.negative;
    final bg = color.withOpacity(0.1);
    final prefix = isPositive ? '+' : '-';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$prefix$currency $amount',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
