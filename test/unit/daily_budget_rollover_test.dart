import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/core/analytics/daily_budget_calculator.dart';
import 'package:money_manager/models/transaction.dart';

void main() {
  group('DailySpendingCalculator Tests (F05 & F06)', () {
    test('Calculates base daily allowance deterministically with minor unit remainder', () {
      // 1000.00 currency = 100000 minor units
      // April has 30 days. 100000 ~/ 30 = 3333, remainder = 10.
      // Days 1..10 get 3334 minor units (33.34), days 11..30 get 3333 minor units (33.33).
      // Sum = 10 * 3334 + 20 * 3333 = 33340 + 66660 = 100000 exact!
      final summary = DailySpendingCalculator.calculate(
        year: 2026,
        month: 4,
        monthlyBudgetMinor: 100000,
        transactions: [],
        referenceDate: DateTime(2026, 4, 30),
      );

      expect(summary.totalDays, 30);
      expect(summary.totalBudgetMinor, 100000);
      expect(summary.days.length, 30);

      int sumBase = 0;
      for (int i = 0; i < 30; i++) {
        final day = summary.days[i];
        sumBase += day.baseAllowanceMinor;
        if (i < 10) {
          expect(day.baseAllowanceMinor, 3334);
        } else {
          expect(day.baseAllowanceMinor, 3333);
        }
      }
      expect(sumBase, 100000);
    });

    test('Positive rollover (under-spending) carries forward to next day', () {
      // 3000 budget for 30 days = 100/day = 10000 minor units/day
      // Day 1: spent 6000 minor units (60.00). Carried out = 10000 - 6000 = +4000
      // Day 2: carried in = +4000. Available = 10000 + 4000 = 14000. Spent 0. Carried out = +14000.
      final txs = [
        Transaction(
          id: 1,
          accountId: 1,
          categoryId: 10,
          title: 'Lunch',
          amount: 60.0,
          amountMinor: 6000,
          type: 'expense',
          date: DateTime(2026, 4, 1, 12, 0),
          isBudgetIncluded: true,
        ),
      ];

      final summary = DailySpendingCalculator.calculate(
        year: 2026,
        month: 4,
        monthlyBudgetMinor: 300000,
        transactions: txs,
        referenceDate: DateTime(2026, 4, 2),
      );

      final day1 = summary.days[0];
      expect(day1.dayNumber, 1);
      expect(day1.baseAllowanceMinor, 10000);
      expect(day1.carriedInMinor, 0);
      expect(day1.availableMinor, 10000);
      expect(day1.actualSpentMinor, 6000);
      expect(day1.carriedOutMinor, 4000);
      expect(day1.status, 'under');

      final day2 = summary.days[1];
      expect(day2.dayNumber, 2);
      expect(day2.carriedInMinor, 4000);
      expect(day2.availableMinor, 14000);
      expect(day2.actualSpentMinor, 0);
      expect(day2.carriedOutMinor, 14000);
      expect(day2.status, 'under');
    });

    test('Negative rollover (over-spending) reduces subsequent day allowance', () {
      // Day 1: spent 15000 minor units (150.00). Available = 10000. Carried out = -5000.
      // Day 2: carried in = -5000. Available = 10000 - 5000 = 5000. Spent 2000. Carried out = 3000.
      final txs = [
        Transaction(
          id: 1,
          accountId: 1,
          categoryId: 10,
          title: 'Grocery bulk',
          amount: 150.0,
          amountMinor: 15000,
          type: 'expense',
          date: DateTime(2026, 4, 1, 14, 0),
          isBudgetIncluded: true,
        ),
        Transaction(
          id: 2,
          accountId: 1,
          categoryId: 10,
          title: 'Coffee',
          amount: 20.0,
          amountMinor: 2000,
          type: 'expense',
          date: DateTime(2026, 4, 2, 9, 0),
          isBudgetIncluded: true,
        ),
      ];

      final summary = DailySpendingCalculator.calculate(
        year: 2026,
        month: 4,
        monthlyBudgetMinor: 300000,
        transactions: txs,
        referenceDate: DateTime(2026, 4, 2),
      );

      final day1 = summary.days[0];
      expect(day1.status, 'over');
      expect(day1.carriedOutMinor, -5000);

      final day2 = summary.days[1];
      expect(day2.carriedInMinor, -5000);
      expect(day2.availableMinor, 5000);
      expect(day2.actualSpentMinor, 2000);
      expect(day2.carriedOutMinor, 3000);
      expect(day2.status, 'under');
    });

    test('is_budget_included = false does NOT deduct from daily spend or rollover', () {
      // Reimbursable expense of 100.00 on Day 1 with is_budget_included = false
      final txs = [
        Transaction(
          id: 1,
          accountId: 1,
          categoryId: 10,
          title: 'Client Dinner (Reimbursable)',
          amount: 100.0,
          amountMinor: 10000,
          type: 'expense',
          date: DateTime(2026, 4, 1, 19, 0),
          isBudgetIncluded: false, // EXCLUDED
        ),
        Transaction(
          id: 2,
          accountId: 1,
          categoryId: 10,
          title: 'Personal Snack',
          amount: 15.0,
          amountMinor: 1500,
          type: 'expense',
          date: DateTime(2026, 4, 1, 20, 0),
          isBudgetIncluded: true, // INCLUDED
        ),
      ];

      final summary = DailySpendingCalculator.calculate(
        year: 2026,
        month: 4,
        monthlyBudgetMinor: 300000,
        transactions: txs,
        referenceDate: DateTime(2026, 4, 1),
      );

      final day1 = summary.days[0];
      // Only personal snack (15.00 = 1500 minor units) should count
      expect(day1.actualSpentMinor, 1500);
      expect(day1.actualSpent, 15.0);
      expect(day1.availableMinor, 10000);
      expect(day1.carriedOutMinor, 8500);
      expect(day1.status, 'under');
    });

    test('Handles leap year February correctly (29 days)', () {
      final summary = DailySpendingCalculator.calculate(
        year: 2024, // Leap year
        month: 2,
        monthlyBudgetMinor: 290000,
        transactions: [],
        referenceDate: DateTime(2024, 2, 29),
      );

      expect(summary.totalDays, 29);
      expect(summary.days.length, 29);
      expect(summary.days.last.dayNumber, 29);
      expect(summary.days.first.baseAllowanceMinor, 10000);
    });

    test('Category filtering isolates spending to chosen category', () {
      final txs = [
        Transaction(
          id: 1,
          accountId: 1,
          categoryId: 1, // Food
          title: 'Groceries',
          amount: 50.0,
          amountMinor: 5000,
          type: 'expense',
          date: DateTime(2026, 4, 1),
          isBudgetIncluded: true,
        ),
        Transaction(
          id: 2,
          accountId: 1,
          categoryId: 2, // Entertainment
          title: 'Movie',
          amount: 30.0,
          amountMinor: 3000,
          type: 'expense',
          date: DateTime(2026, 4, 1),
          isBudgetIncluded: true,
        ),
      ];

      final foodSummary = DailySpendingCalculator.calculate(
        year: 2026,
        month: 4,
        monthlyBudgetMinor: 150000, // 50/day
        transactions: txs,
        categoryId: 1,
        referenceDate: DateTime(2026, 4, 1),
      );

      expect(foodSummary.days[0].actualSpentMinor, 5000);
      expect(foodSummary.days[0].transactions.length, 1);
      expect(foodSummary.days[0].transactions.first.title, 'Groceries');
    });
  });
}
