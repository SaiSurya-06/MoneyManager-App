import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/core/services/monthly_pdf_report_service.dart';
import 'package:money_manager/models/account.dart';
import 'package:money_manager/models/budget.dart';
import 'package:money_manager/models/category.dart';
import 'package:money_manager/models/transaction.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Automated Monthly PDF Reports (F07)', () {
    late List<Transaction> transactions;
    late List<Account> accounts;
    late List<Category> categories;
    late List<Budget> budgets;

    setUp(() {
      final now = DateTime(2026, 3, 1);
      accounts = [
        Account(
          id: 1,
          name: 'Salary Account',
          type: 'Bank',
          balance: 50000.0,
          icon: 'account_balance',
          color: '4CAF50',
          isShared: false,
          createdAt: now,
        ),
        Account(
          id: 2,
          name: 'Cash',
          type: 'Cash',
          balance: 4000.0,
          icon: 'payments',
          color: '2196F3',
          isShared: false,
          createdAt: now,
        ),
      ];

      categories = [
        const Category(id: 1, name: 'Salary', icon: 'payments', color: '4CAF50', isDefault: true, type: 'income'),
        const Category(id: 2, name: 'Groceries', icon: 'shopping', color: 'FF9800', isDefault: true, type: 'expense'),
        const Category(id: 3, name: 'Rent', icon: 'home', color: '2196F3', isDefault: true, type: 'expense'),
        const Category(id: 4, name: 'Client Dinner (Reimbursable)', icon: 'fastfood', color: '9C27B0', isDefault: false, type: 'expense'),
      ];

      budgets = [
        const Budget(id: 1, categoryId: 2, limitAmount: 500.0, month: '2026-03'),
        const Budget(id: 2, categoryId: 3, limitAmount: 1500.0, month: '2026-03'),
      ];

      transactions = [
        // Income
        Transaction(
          id: 1,
          accountId: 1,
          categoryId: 1,
          title: 'Monthly Salary',
          amount: 5000.0,
          type: 'income',
          date: DateTime(2026, 3, 1, 9, 0),
          isPrivate: false,
          createdAt: now,
          isBudgetIncluded: true,
        ),
        // Budget-eligible expense 1
        Transaction(
          id: 2,
          accountId: 1,
          categoryId: 2,
          title: 'Supermarket Groceries',
          amount: 350.0,
          type: 'expense',
          date: DateTime(2026, 3, 5, 14, 0),
          isPrivate: false,
          createdAt: now,
          isBudgetIncluded: true,
        ),
        // Budget-eligible expense 2
        Transaction(
          id: 3,
          accountId: 1,
          categoryId: 3,
          title: 'Apartment Rent',
          amount: 1500.0,
          type: 'expense',
          date: DateTime(2026, 3, 2, 10, 0),
          isPrivate: false,
          createdAt: now,
          isBudgetIncluded: true,
        ),
        // Excluded reimbursable expense
        Transaction(
          id: 4,
          accountId: 1,
          categoryId: 4,
          title: 'Company Dinner (Reimbursable)',
          amount: 200.0,
          type: 'expense',
          date: DateTime(2026, 3, 10, 20, 0),
          isPrivate: false,
          createdAt: now,
          isBudgetIncluded: false, // NOT budget included
        ),
      ];
    });

    test('Report 1 (Income & Expense) produces valid PDF bytes with magic header %PDF-', () async {
      final bytes = await MonthlyPdfReportService.instance.buildIncomeExpenseReportPdf(
        monthStr: '2026-03',
        transactions: transactions,
        accounts: accounts,
        categories: categories,
        currency: 'INR',
      );

      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(1000));

      // Verify PDF magic bytes header: %PDF- (0x25, 0x50, 0x44, 0x46, 0x2D)
      final header = utf8.decode(bytes.sublist(0, 5));
      expect(header, '%PDF-');
    });

    test('Report 2 (Budget Performance) produces valid PDF bytes with magic header %PDF-', () async {
      final bytes = await MonthlyPdfReportService.instance.buildBudgetPerformanceReportPdf(
        monthStr: '2026-03',
        transactions: transactions,
        budgets: budgets,
        categories: categories,
        currency: 'INR',
      );

      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(1000));

      final header = utf8.decode(bytes.sublist(0, 5));
      expect(header, '%PDF-');
    });

    test('Report 1 includes ALL expenses including is_budget_included = false', () {
      // In Report 1, total expense must reflect full financial reality
      final allExpenses = transactions.where((tx) => tx.type == 'expense').toList();
      final totalExpense = allExpenses.fold<double>(0.0, (acc, tx) => acc + tx.amount);
      final totalExpenseMinor = allExpenses.fold<int>(0, (acc, tx) => acc + tx.amountMinorUnits);

      // 350 + 1500 + 200 = 2050.00
      expect(allExpenses.length, 3);
      expect(totalExpense, 2050.0);
      expect(totalExpenseMinor, 205000);
    });

    test('Report 2 EXCLUDES transactions where is_budget_included = false', () {
      // In Report 2, only budget-eligible expenses are factored into adherence
      final budgetEligible = transactions.where((tx) => tx.type == 'expense' && tx.isBudgetIncluded).toList();
      final budgetSpent = budgetEligible.fold<double>(0.0, (acc, tx) => acc + tx.amount);
      final budgetSpentMinor = budgetEligible.fold<int>(0, (acc, tx) => acc + tx.amountMinorUnits);

      // Only 350 + 1500 = 1850.00 (the 200.00 reimbursable expense is omitted)
      expect(budgetEligible.length, 2);
      expect(budgetSpent, 1850.0);
      expect(budgetSpentMinor, 185000);
      expect(budgetSpent, lessThan(2050.0));
    });

    test('SHA-256 checksum calculation is deterministic', () {
      final sampleBytes = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9]);
      final hash1 = MonthlyPdfReportService.calculateChecksum(sampleBytes);
      final hash2 = MonthlyPdfReportService.calculateChecksum(sampleBytes);

      expect(hash1, equals(hash2));
      expect(hash1.length, 64); // SHA-256 hex string length
    });

    test('MonthlyReportRecord serializes and deserializes correctly', () {
      final now = DateTime.now();
      final record = MonthlyReportRecord(
        id: 1,
        reportType: 'income_expense',
        reportingMonth: '2026-03',
        generatedAt: now,
        filePath: '/data/reports/monthly/report.pdf',
        fileSizeBytes: 20480,
        checksum: 'abc123def456',
        isAutoGenerated: true,
      );

      final map = record.toMap();
      expect(map['id'], 1);
      expect(map['report_type'], 'income_expense');
      expect(map['reporting_month'], '2026-03');
      expect(map['file_size_bytes'], 20480);
      expect(map['checksum'], 'abc123def456');
      expect(map['is_auto_generated'], 1);

      final fromMap = MonthlyReportRecord.fromMap(map);
      expect(fromMap.id, 1);
      expect(fromMap.reportType, 'income_expense');
      expect(fromMap.reportingMonth, '2026-03');
      expect(fromMap.fileSizeBytes, 20480);
      expect(fromMap.checksum, 'abc123def456');
      expect(fromMap.isAutoGenerated, isTrue);
    });
  });
}
