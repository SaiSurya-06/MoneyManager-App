// lib/theme/screen_overrides.dart
import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Screen-specific decoration specifications enforcing theme consistency.
class ScreenOverrides {
  /// Dashboard / Home Screen Specs
  static BoxDecoration netWorthCardDecoration(bool isDark) => BoxDecoration(
    gradient: LinearGradient(
      colors: isDark
          ? [const Color(0xFFE53935), AppColors.gold]
          : [const Color(0xFFE53935), const Color(0xFFD4AF37)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
        color: AppColors.gold.withValues(alpha: isDark ? 0.25 : 0.15),
        blurRadius: 16,
        offset: const Offset(0, 6),
      ),
    ],
  );

  /// Transaction Swipe to Delete background
  static BoxDecoration swipeToDeleteDecoration() => BoxDecoration(
    color: AppColors.expense,
    borderRadius: BorderRadius.circular(12),
  );

  /// Over Budget Warning Banner
  static BoxDecoration budgetAlertDecoration() => BoxDecoration(
    color: AppColors.expense.withValues(alpha: 0.12),
    borderRadius: BorderRadius.circular(12),
    border: const Border(left: BorderSide(color: AppColors.expense, width: 4)),
  );

  /// Debt Tracker Liability Card Border Accent
  static BorderSide debtCardLeftBorder() => const BorderSide(color: AppColors.expense, width: 4);

  /// Debt Tracker Receivable Card Border Accent
  static BorderSide receivableCardLeftBorder() => const BorderSide(color: AppColors.income, width: 4);
}
