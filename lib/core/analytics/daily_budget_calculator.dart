import '../../models/transaction.dart';

/// Represents a single day in the Money Map Daily Spending Calendar.
class DailyBudgetDay {
  final DateTime date;
  final int dayNumber;
  final int baseAllowanceMinor;
  final int carriedInMinor;
  final int availableMinor;
  final int actualSpentMinor;
  final int carriedOutMinor;
  final String status; // 'under', 'at', 'over', 'future'
  final List<Transaction> transactions;

  const DailyBudgetDay({
    required this.date,
    required this.dayNumber,
    required this.baseAllowanceMinor,
    required this.carriedInMinor,
    required this.availableMinor,
    required this.actualSpentMinor,
    required this.carriedOutMinor,
    required this.status,
    required this.transactions,
  });

  double get baseAllowance => baseAllowanceMinor / 100.0;
  double get carriedIn => carriedInMinor / 100.0;
  double get available => availableMinor / 100.0;
  double get actualSpent => actualSpentMinor / 100.0;
  double get carriedOut => carriedOutMinor / 100.0;

  bool get isUnderBudget => status == 'under';
  bool get isOverBudget => status == 'over';
  bool get isAtBudget => status == 'at';
  bool get isFuture => status == 'future';
}

/// Represents the monthly overview summary for daily spending and rollover.
class DailyBudgetMonthSummary {
  final int totalBudgetMinor;
  final int totalSpentMinor;
  final int netRolloverBalanceMinor;
  final int totalDays;
  final int currentDay;
  final List<DailyBudgetDay> days;

  const DailyBudgetMonthSummary({
    required this.totalBudgetMinor,
    required this.totalSpentMinor,
    required this.netRolloverBalanceMinor,
    required this.totalDays,
    required this.currentDay,
    required this.days,
  });

  double get totalBudget => totalBudgetMinor / 100.0;
  double get totalSpent => totalSpentMinor / 100.0;
  double get netRolloverBalance => netRolloverBalanceMinor / 100.0;
  String get status => netRolloverBalanceMinor >= 0 ? 'Under Budget' : 'Over Budget';
}

/// Computes daily allowances, daily spending, and chronological rollovers
/// using exact integer minor units (paise/cents).
class DailySpendingCalculator {
  static DailyBudgetMonthSummary calculate({
    required int year,
    required int month,
    required int monthlyBudgetMinor,
    required List<Transaction> transactions,
    int? categoryId,
    DateTime? referenceDate,
  }) {
    final ref = referenceDate ?? DateTime.now();
    final totalDays = DateTime(year, month + 1, 0).day;

    int effectiveToday;
    if (year == ref.year && month == ref.month) {
      effectiveToday = ref.day.clamp(1, totalDays);
    } else if (year < ref.year || (year == ref.year && month < ref.month)) {
      effectiveToday = totalDays; // Entire month is past
    } else {
      effectiveToday = 0; // Entire month is future
    }

    // Distribute monthly budget into base daily allowances deterministically
    final baseDailyMinor = monthlyBudgetMinor ~/ totalDays;
    final remainderMinor = monthlyBudgetMinor % totalDays;

    // Filter eligible expense transactions (where type == 'expense' and isBudgetIncluded == true)
    final eligibleTxs = transactions.where((tx) {
      if (tx.type != 'expense') return false;
      if (!tx.isBudgetIncluded) return false;
      if (categoryId != null && tx.categoryId != categoryId) return false;
      return tx.date.year == year && tx.date.month == month;
    }).toList();

    // Group transactions by day
    final Map<int, List<Transaction>> txsByDay = {};
    final Map<int, int> spendByDay = {};

    for (var tx in eligibleTxs) {
      final day = tx.date.day;
      txsByDay.putIfAbsent(day, () => []).add(tx);
      spendByDay[day] = (spendByDay[day] ?? 0) + tx.amountMinorUnits;
    }

    final List<DailyBudgetDay> days = [];
    int carriedIn = 0;
    int cumulativeSpentMinor = 0;

    for (int day = 1; day <= totalDays; day++) {
      final date = DateTime(year, month, day);
      final baseAllowance = baseDailyMinor + (day <= remainderMinor ? 1 : 0);
      final dayTxs = txsByDay[day] ?? const [];

      if (day <= effectiveToday) {
        final available = baseAllowance + carriedIn;
        final spent = spendByDay[day] ?? 0;
        final carriedOut = available - spent;
        cumulativeSpentMinor += spent;

        final String dayStatus;
        if (spent < available) {
          dayStatus = 'under';
        } else if (spent == available) {
          dayStatus = 'at';
        } else {
          dayStatus = 'over';
        }

        days.add(DailyBudgetDay(
          date: date,
          dayNumber: day,
          baseAllowanceMinor: baseAllowance,
          carriedInMinor: carriedIn,
          availableMinor: available,
          actualSpentMinor: spent,
          carriedOutMinor: carriedOut,
          status: dayStatus,
          transactions: dayTxs,
        ));

        carriedIn = carriedOut;
      } else {
        // Future day
        days.add(DailyBudgetDay(
          date: date,
          dayNumber: day,
          baseAllowanceMinor: baseAllowance,
          carriedInMinor: 0,
          availableMinor: baseAllowance,
          actualSpentMinor: 0,
          carriedOutMinor: 0,
          status: 'future',
          transactions: dayTxs,
        ));
      }
    }

    final netRollover = effectiveToday > 0 && days.isNotEmpty
        ? days[effectiveToday - 1].carriedOutMinor
        : 0;

    return DailyBudgetMonthSummary(
      totalBudgetMinor: monthlyBudgetMinor,
      totalSpentMinor: cumulativeSpentMinor,
      netRolloverBalanceMinor: netRollover,
      totalDays: totalDays,
      currentDay: effectiveToday,
      days: days,
    );
  }
}
