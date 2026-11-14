import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:money_manager/core/database/database.dart';
import 'package:money_manager/core/database/daos/account_dao.dart';
import 'package:money_manager/core/database/daos/transaction_dao.dart';
import 'package:money_manager/models/account.dart';
import 'package:money_manager/models/transaction.dart';

void main() {
  late Database db;
  late AccountDao accountDao;
  late TransactionDao transactionDao;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    AppDatabase.setMockDatabase(db);
    accountDao = AccountDao();
    transactionDao = TransactionDao();

    await db.execute('''
      CREATE TABLE account (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        balance REAL NOT NULL DEFAULT 0.0,
        balance_minor INTEGER NOT NULL DEFAULT 0,
        icon TEXT NOT NULL,
        color TEXT NOT NULL,
        is_shared INTEGER NOT NULL DEFAULT 1,
        is_archived INTEGER NOT NULL DEFAULT 0,
        archived_at TEXT,
        billing_cycle_start_day INTEGER,
        statement_due_day INTEGER,
        minimum_due REAL,
        minimum_due_minor INTEGER,
        limit_amount REAL,
        limit_amount_minor INTEGER,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE transaction_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_id INTEGER NOT NULL,
        category_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        amount_minor INTEGER NOT NULL DEFAULT 0,
        type TEXT NOT NULL,
        date TEXT NOT NULL,
        note TEXT,
        recurrence TEXT NOT NULL DEFAULT 'none',
        recurrence_end_date TEXT,
        is_private INTEGER NOT NULL DEFAULT 0,
        tags TEXT NOT NULL DEFAULT '',
        parent_id INTEGER,
        transfer_to_account_id INTEGER,
        created_at TEXT NOT NULL,
        subcategory_id INTEGER,
        is_budget_included INTEGER NOT NULL DEFAULT 1
      )
    ''');
  });

  tearDown(() async {
    await db.close();
  });

  group('F03: Credit Card Management & Non-Duplicate Accounting Tests', () {
    test('Credit Card creation, available credit calculation, and billing cycle fields', () async {
      final cc = Account(
        name: 'ICICI Amazon Pay',
        type: 'Credit Card',
        balance: 0.00,
        icon: 'credit_card',
        color: '#E53935',
        isShared: true,
        createdAt: DateTime(2026, 1, 1),
        limitAmount: 100000.00,
        billingCycleStartDay: 12,
        statementDueDay: 2,
        minimumDue: 2500.00,
      );

      final ccId = await accountDao.insertAccount(cc);
      final fetched = await accountDao.getAccount(ccId);

      expect(fetched, isNotNull);
      expect(fetched!.limitAmount, equals(100000.00));
      expect(fetched.availableCredit, equals(100000.00));
      expect(fetched.pendingPayment, equals(0.00));
      expect(fetched.billingCycleStartDay, equals(12));
      expect(fetched.statementDueDay, equals(2));
      expect(fetched.minimumDue, equals(2500.00));
    });

    test('Purchase increases CC liability, and settlement transfer eliminates duplicate expense', () async {
      // 1. Create Bank Account with ₹50,000
      final bank = Account(
        name: 'HDFC Salary',
        type: 'Bank',
        balance: 50000.00,
        icon: 'account_balance',
        color: '#1E88E5',
        isShared: true,
        createdAt: DateTime(2026, 1, 1),
      );
      final bankId = await accountDao.insertAccount(bank);

      // 2. Create Credit Card with ₹100,000 limit
      final cc = Account(
        name: 'SBI Card',
        type: 'Credit Card',
        balance: 0.00,
        icon: 'credit_card',
        color: '#E53935',
        isShared: true,
        createdAt: DateTime(2026, 1, 1),
        limitAmount: 100000.00,
      );
      final ccId = await accountDao.insertAccount(cc);

      // 3. User makes an expense purchase of ₹15,000 on the Credit Card
      final purchaseTx = Transaction(
        accountId: ccId,
        categoryId: 1, // Electronics
        title: 'New Monitor',
        amount: 15000.00,
        type: 'expense',
        date: DateTime(2026, 10, 5),
        isPrivate: false,
        isBudgetIncluded: true,
        createdAt: DateTime.now(),
      );
      await transactionDao.insertTransaction(purchaseTx);

      // Verify Credit Card balance and available credit
      var updatedCC = (await accountDao.getAccount(ccId))!;
      expect(updatedCC.balance, equals(-15000.00)); // Negative balance represents debt
      expect(updatedCC.pendingPayment, equals(15000.00)); // Liability to pay
      expect(updatedCC.availableCredit, equals(85000.00)); // 100,000 - 15,000 = 85,000 available

      // Verify Bank balance is untouched yet
      var updatedBank = (await accountDao.getAccount(bankId))!;
      expect(updatedBank.balance, equals(50000.00));

      // 4. Bill payment: transfer ₹15,000 from Bank to Credit Card (settlement)
      final paymentTx = Transaction(
        accountId: bankId,
        categoryId: 2, // Credit Card Payment
        title: 'SBI Card Bill Payment',
        amount: 15000.00,
        type: 'transfer',
        transferToAccountId: ccId,
        date: DateTime(2026, 10, 25),
        isPrivate: false,
        isBudgetIncluded: false, // Liability settlement is NOT an expense deduction
        createdAt: DateTime.now(),
      );
      await transactionDao.insertTransaction(paymentTx);

      // 5. Verify balances after payment:
      // Bank balance debited: 50,000 - 15,000 = 35,000
      updatedBank = (await accountDao.getAccount(bankId))!;
      expect(updatedBank.balance, equals(35000.00));

      // Credit Card liability extinguished: -15,000 + 15,000 = 0.0
      updatedCC = (await accountDao.getAccount(ccId))!;
      expect(updatedCC.balance, equals(0.00));
      expect(updatedCC.pendingPayment, equals(0.00));
      expect(updatedCC.availableCredit, equals(100000.00)); // Restored to full limit
    });
  });
}
