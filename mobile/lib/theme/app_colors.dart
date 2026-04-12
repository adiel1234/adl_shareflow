import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand gradient
  static const Color primary = Color(0xFF1E40AF);   // Blue
  static const Color secondary = Color(0xFF059669);  // Green

  // Semantic
  static const Color positive = Color(0xFF059669);   // credit / gain
  static const Color negative = Color(0xFFDC2626);   // debt / loss
  static const Color neutral = Color(0xFF6B7280);    // neutral balance

  // Backgrounds
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF1F5F9);

  // Text
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textDisabled = Color(0xFF94A3B8);

  // Border
  static const Color border = Color(0xFFE2E8F0);
  static const Color divider = Color(0xFFF1F5F9);

  // Status
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFD97706);
  static const Color error = Color(0xFFDC2626);
  static const Color info = Color(0xFF2563EB);

  // Category colors
  static const Color categoryFood = Color(0xFFF97316);
  static const Color categoryTravel = Color(0xFF8B5CF6);
  static const Color categoryHousing = Color(0xFF0EA5E9);
  static const Color categoryTransport = Color(0xFF10B981);
  static const Color categoryEntertainment = Color(0xFFEC4899);
  static const Color categoryOther = Color(0xFF6B7280);

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
    colors: [primary, secondary],
  );

  static const LinearGradient positiveGradient = LinearGradient(
    colors: [Color(0xFF059669), Color(0xFF34D399)],
  );

  static const LinearGradient negativeGradient = LinearGradient(
    colors: [Color(0xFFDC2626), Color(0xFFF87171)],
  );
}
