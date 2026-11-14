import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/models/transaction.dart';

void main() {
  group('Transaction Budget Inclusion / Exclusion (F06)', () {
    test('Default isBudgetIncluded is true', () {
      final tx = Transaction(
        id: 1,
        accountId: 1,
        categoryId: 2,
        title: 'Dinner',
        amount: 50.0,
        type: 'expense',
        date: DateTime.now(),
      );

      expect(tx.isBudgetIncluded, isTrue);
      final map = tx.toMap();
      expect(map['is_budget_included'], 1);
    });

    test('Explicit isBudgetIncluded = false serializes to 0 in database map', () {
      final tx = Transaction(
        id: 2,
        accountId: 1,
        categoryId: 2,
        title: 'Business lunch (Reimbursable)',
        amount: 120.0,
        amountMinor: 12000,
        type: 'expense',
        date: DateTime.now(),
        isBudgetIncluded: false,
      );

      expect(tx.isBudgetIncluded, isFalse);
      final map = tx.toMap();
      expect(map['is_budget_included'], 0);

      final fromMap = Transaction.fromMap(map);
      expect(fromMap.isBudgetIncluded, isFalse);
      expect(fromMap.amountMinorUnits, 12000);
    });

    test('Budget filtering isolates only budget-included transactions', () {
      final txList = [
        Transaction(
          id: 1,
          accountId: 1,
          categoryId: 10,
          title: 'Groceries',
          amount: 80.0,
          amountMinor: 8000,
          type: 'expense',
          date: DateTime(2026, 4, 1),
          isBudgetIncluded: true,
        ),
        Transaction(
          id: 2,
          accountId: 1,
          categoryId: 10,
          title: 'Client Dinner (Reimbursable by Employer)',
          amount: 250.0,
          amountMinor: 25000,
          type: 'expense',
          date: DateTime(2026, 4, 2),
          isBudgetIncluded: false, // Excluded from budget
        ),
        Transaction(
          id: 3,
          accountId: 1,
          categoryId: 10,
          title: 'Household supplies',
          amount: 40.0,
          amountMinor: 4000,
          type: 'expense',
          date: DateTime(2026, 4, 3),
          isBudgetIncluded: true,
        ),
      ];

      // Total financial expense outflow (Analytics, Ledger, Net Cash flow)
      final totalFinancialOutflow = txList.fold<double>(0.0, (acc, tx) => acc + tx.amount);
      expect(totalFinancialOutflow, 370.0);

      // Budget-eligible spending (Budgets, Daily Rollover)
      final budgetEligibleExpenses = txList.where((tx) => tx.isBudgetIncluded).toList();
      final totalBudgetSpend = budgetEligibleExpenses.fold<double>(0.0, (acc, tx) => acc + tx.amount);
      final totalBudgetSpendMinor = budgetEligibleExpenses.fold<int>(0, (acc, tx) => acc + tx.amountMinorUnits);

      expect(budgetEligibleExpenses.length, 2);
      expect(totalBudgetSpend, 120.0);
      expect(totalBudgetSpendMinor, 12000);

      // The 250.00 reimbursable expense was completely excluded from budget spending!
      expect(totalBudgetSpend, isNot(equals(totalFinancialOutflow)));
    });
  });
}
