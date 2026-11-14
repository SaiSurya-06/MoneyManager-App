import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/models/account.dart';
import 'package:money_manager/models/category.dart';
import 'package:money_manager/models/transaction_template.dart';

void main() {
  group('Quick-Add Templates with Account Name (F04)', () {
    final now = DateTime(2026, 1, 1);

    test('TransactionTemplate holds valid accountId and categoryId', () {
      final tmpl = TransactionTemplate(
        id: 1,
        title: 'Morning Metro',
        amount: 50.0,
        type: 'expense',
        categoryId: 5,
        accountId: 2,
      );

      expect(tmpl.id, 1);
      expect(tmpl.title, 'Morning Metro');
      expect(tmpl.amount, 50.0);
      expect(tmpl.amountMinorUnits, 5000);
      expect(tmpl.categoryId, 5);
      expect(tmpl.accountId, 2);
      expect(tmpl.type, 'expense');

      final map = tmpl.toMap();
      expect(map['account_id'], 2);
      expect(map['category_id'], 5);
      expect(map['amount_minor'], 5000);

      final fromMap = TransactionTemplate.fromMap(map);
      expect(fromMap.accountId, 2);
      expect(fromMap.categoryId, 5);
      expect(fromMap.amountMinorUnits, 5000);
    });

    test('Resolves active account name successfully', () {
      final accounts = [
        Account(
          id: 1,
          name: 'HDFC Bank',
          type: 'Bank',
          balance: 5000.0,
          icon: 'account_balance',
          color: '4CAF50',
          isShared: false,
          createdAt: now,
          isArchived: false,
        ),
        Account(
          id: 2,
          name: 'Paytm Wallet',
          type: 'Wallet',
          balance: 1200.0,
          icon: 'payments',
          color: '2196F3',
          isShared: false,
          createdAt: now,
          isArchived: false,
        ),
      ];

      final tmpl = TransactionTemplate(
        id: 1,
        title: 'Metro',
        amount: 30.0,
        type: 'expense',
        categoryId: 3,
        accountId: 2,
      );

      final accountMap = {for (var a in accounts) a.id: a};
      final acc = accountMap[tmpl.accountId];

      expect(acc, isNotNull);
      expect(acc!.name, 'Paytm Wallet');
      expect(acc.isArchived, isFalse);
    });

    test('Detects archived account and flags as unavailable', () {
      final accounts = [
        Account(
          id: 1,
          name: 'Active Bank',
          type: 'Bank',
          balance: 1000.0,
          icon: 'account_balance',
          color: '4CAF50',
          isShared: false,
          createdAt: now,
          isArchived: false,
        ),
        Account(
          id: 2,
          name: 'Old Closed Card',
          type: 'Credit Card',
          balance: 0.0,
          icon: 'credit_card',
          color: 'F44336',
          isShared: false,
          createdAt: now,
          isArchived: true,
        ),
      ];

      final tmpl = TransactionTemplate(
        id: 2,
        title: 'Old Subscription',
        amount: 299.0,
        type: 'expense',
        categoryId: 4,
        accountId: 2, // Points to archived account
      );

      final accountMap = {for (var a in accounts) a.id: a};
      final acc = accountMap[tmpl.accountId];

      expect(acc, isNotNull);
      expect(acc!.name, 'Old Closed Card');
      expect(acc.isArchived, isTrue);

      final isUnavailable = acc.isArchived;
      expect(isUnavailable, isTrue);
    });

    test('Detects missing account when account has been deleted', () {
      final accounts = [
        Account(
          id: 1,
          name: 'Main Account',
          type: 'Bank',
          balance: 2000.0,
          icon: 'account_balance',
          color: '4CAF50',
          isShared: false,
          createdAt: now,
          isArchived: false,
        ),
      ];

      final tmpl = TransactionTemplate(
        id: 3,
        title: 'Gym',
        amount: 1500.0,
        type: 'expense',
        categoryId: 6,
        accountId: 999, // Non-existent account
      );

      final accountMap = {for (var a in accounts) a.id: a};
      final acc = accountMap[tmpl.accountId];

      expect(acc, isNull);
    });

    test('Gracefully falls back to Uncategorized if category is deleted', () {
      final categories = [
        const Category(id: 1, name: 'Groceries', icon: 'shopping', color: '4CAF50', isDefault: false),
      ];

      final tmpl = TransactionTemplate(
        id: 4,
        title: 'Unknown Expense',
        amount: 100.0,
        type: 'expense',
        categoryId: 99, // Non-existent category
        accountId: 1,
      );

      final categoryMap = {for (var c in categories) c.id: c.name};
      final categoryName = categoryMap[tmpl.categoryId] ?? 'Uncategorized';

      expect(categoryName, 'Uncategorized');
    });
  });
}
