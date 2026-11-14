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

    // Create schema with v13 definitions
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
        is_budget_included INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (account_id) REFERENCES account (id) ON DELETE CASCADE,
        FOREIGN KEY (category_id) REFERENCES category (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE category (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        icon TEXT NOT NULL,
        color TEXT NOT NULL,
        is_default INTEGER NOT NULL DEFAULT 0,
        type TEXT NOT NULL DEFAULT 'both'
      )
    ''');
  });

  tearDown(() async {
    await db.close();
  });

  group('F02: Account Archiving and Safe Deletion Tests', () {
    test('Archiving an account preserves records, sets is_archived=1, and preserves balance', () async {
      final acc = Account(
        name: 'Salary Account',
        type: 'Bank',
        balance: 50000.00,
        icon: 'account_balance',
        color: '#1E88E5',
        isShared: true,
        createdAt: DateTime(2026, 1, 1),
      );
      final accId = await accountDao.insertAccount(acc);

      // Verify created as active
      var fetched = await accountDao.getAccount(accId);
      expect(fetched, isNotNull);
      expect(fetched!.isArchived, isFalse);
      expect(fetched.balance, equals(50000.00));

      // Archive account
      await accountDao.archiveAccount(accId);

      fetched = await accountDao.getAccount(accId);
      expect(fetched!.isArchived, isTrue);
      expect(fetched.archivedAt, isNotNull);
      expect(fetched.balance, equals(50000.00)); // Balance unchanged

      // Restore account
      await accountDao.restoreAccount(accId);

      fetched = await accountDao.getAccount(accId);
      expect(fetched!.isArchived, isFalse);
      expect(fetched.archivedAt, isNull);
      expect(fetched.balance, equals(50000.00));
    });

    test('Safe deletion prevents permanent deletion of account with transactions', () async {
      final acc = Account(
        name: 'Daily Wallet',
        type: 'Cash',
        balance: 1000.00,
        icon: 'payments',
        color: '#4CAF50',
        isShared: true,
        createdAt: DateTime(2026, 1, 1),
      );
      final accId = await accountDao.insertAccount(acc);

      // Add a transaction
      final tx = Transaction(
        accountId: accId,
        categoryId: 1,
        title: 'Coffee',
        amount: 150.00,
        type: 'expense',
        date: DateTime(2026, 10, 1),
        isPrivate: false,
        createdAt: DateTime.now(),
      );
      await transactionDao.insertTransaction(tx);

      // Verify transaction exists
      final txCount = await accountDao.getTransactionCountForAccount(accId);
      expect(txCount, equals(1));

      // Attempting deleteAccount MUST throw StateError
      expect(
        () async => await accountDao.deleteAccount(accId),
        throwsA(isA<StateError>()),
      );

      // Verify account and transaction still exist in database unharmed
      final accountStillExists = await accountDao.getAccount(accId);
      expect(accountStillExists, isNotNull);
      final txsStillExist = await transactionDao.getTransactionsForAccount(accId);
      expect(txsStillExist.length, equals(1));
    });

    test('Empty account with 0 transactions can be safely deleted', () async {
      final acc = Account(
        name: 'Empty Savings',
        type: 'Savings',
        balance: 0.00,
        icon: 'savings',
        color: '#8E24AA',
        isShared: true,
        createdAt: DateTime(2026, 1, 1),
      );
      final accId = await accountDao.insertAccount(acc);

      final txCount = await accountDao.getTransactionCountForAccount(accId);
      expect(txCount, equals(0));

      final rowsDeleted = await accountDao.deleteAccount(accId);
      expect(rowsDeleted, equals(1));

      final fetched = await accountDao.getAccount(accId);
      expect(fetched, isNull);
    });
  });
}
