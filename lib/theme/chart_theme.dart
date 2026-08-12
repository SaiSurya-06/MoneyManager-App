// lib/theme/chart_theme.dart
import 'package:flutter/material.dart';
import 'app_theme.dart';

/// fl_chart color specifications for all chart types.
/// Import and use these in every chart widget — never hardcode colors in charts.
class AppChartColors {
  // ── Line chart series ────────────────────────────────────────────────────
  static const lineIncome     = AppColors.income;        // #00E676 dark / #2ECC71 light
  static const lineExpense    = AppColors.expense;       // #E53935
  static const lineNetWorth   = AppColors.gold;          // #D4AF37
  static const lineProjection = Color(0xFF9090A8);       // muted dashed forecast

  // ── Bar chart ────────────────────────────────────────────────────────────
  static const barIncome      = AppColors.income;
  static const barExpense     = AppColors.expense;
  static const barNeutral     = Color(0xFF5A5A72);

  // ── Pie / donut chart — category palette (max 8 slices) ─────────────────
  static const List<Color> pieSlices = [
    Color(0xFFD4AF37), // gold — primary/food
    Color(0xFF00E676), // green — income/salary
    Color(0xFF2196F3), // blue — transport
    Color(0xFFFF9800), // amber — entertainment
    Color(0xFFE91E63), // pink — health
    Color(0xFF9C27B0), // purple — subscriptions
    Color(0xFF00BCD4), // cyan — utilities
    Color(0xFF607D8B), // blue-grey — other
  ];

  // ── Gradient fills (below line charts) ──────────────────────────────────
  static List<Color> incomeGradient(bool isDark) => [
    (isDark ? AppColors.income : AppColors.incomeLight).withValues(alpha: 0.3),
    (isDark ? AppColors.income : AppColors.incomeLight).withValues(alpha: 0.0),
  ];
  static List<Color> expenseGradient = [
    AppColors.expense.withValues(alpha: 0.25),
    AppColors.expense.withValues(alpha: 0.0),
  ];
  static List<Color> netWorthGradient = [
    AppColors.gold.withValues(alpha: 0.25),
    AppColors.gold.withValues(alpha: 0.0),
  ];

  // ── Budget progress bar ──────────────────────────────────────────────────
  static Color budgetProgress(double ratio) {
    if (ratio >= 1.0) return AppColors.expense;   // over budget → red
    if (ratio >= 0.8) return AppColors.expense;   // warning → red
    return AppColors.income;                      // healthy → green
  }

  // ── Savings goal progress ────────────────────────────────────────────────
  static const savingsGoalTrack    = AppColors.gold;
  static const savingsGoalBg       = Color(0xFF2A2410); // dark
  static const savingsGoalBgLight  = Color(0xFFFFF8DC); // light

  // ── Net worth trend line background ─────────────────────────────────────
  static const netWorthPositive = AppColors.gold;
  static const netWorthNegative = AppColors.expense;

  // ── Anomaly highlight (Z-score outlier) ──────────────────────────────────
  static const anomalyDot = Color(0xFFFF6D00); // amber-orange, distinct from red
}
