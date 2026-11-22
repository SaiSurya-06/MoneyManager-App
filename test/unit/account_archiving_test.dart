import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;
import 'package:money_manager/core/analytics/recurrence_engine.dart';
import 'package:money_manager/core/backup/backup_service.dart';
import 'package:money_manager/core/database/database.dart';
import 'package:money_manager/core/database/daos/account_dao.dart';
import 'package:money_manager/core/database/daos/transaction_dao.dart';
import 'package:money_manager/core/database/daos/user_profile_dao.dart';
import 'package:money_manager/models/account.dart';
import 'package:money_manager/models/transaction.dart';
import 'package:money_manager/models/user_profile.dart';

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
        initial_balance REAL NOT NULL DEFAULT 0.0,
        initial_balance_minor INTEGER NOT NULL DEFAULT 0,
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
    await AppDatabase.instance.upgradeDatabase(db, 15, AppDatabase.schemaVersion);
  });

  tearDown(() async {
    await db.close();
  });

  test('account order persists, appends new accounts, and rejects a stale list',
      () async {
    final account = Account(
      name: 'First account',
      type: 'Bank',
      balance: 100,
      icon: 'account_balance',
      color: '#4CAF50',
      isShared: false,
      createdAt: DateTime(2026, 1, 1),
    );
    final first = await accountDao.insertAccount(account);
    final second = await accountDao.insertAccount(account.copyWith(name: 'Second account'));
    final archived = await accountDao.insertAccount(
      account.copyWith(name: 'Archived account', isArchived: true),
    );
    expect((await accountDao.getAllAccounts()).map((a) => a.id), [first, second, archived]);

    await accountDao.saveActiveAccountOrder([second, first]);
    final newId = await accountDao.insertAccount(account.copyWith(name: 'New account'));
    await expectLater(accountDao.saveActiveAccountOrder([first, second]), throwsStateError);
    await expectLater(accountDao.saveActiveAccountOrder([first, first, newId]), throwsStateError);

    final reloaded = await AccountDao().getAllAccounts(includeArchived: false);
    expect(reloaded.map((a) => a.id), [second, first, newId]);
    expect(reloaded.map((a) => a.balance), [100, 100, 100]);
  });


  test('stale transfer edits and repeated deletes preserve both balances', () async {
    final date = DateTime(2026, 1, 1);
    final source = Account(
      name: 'Checking',
      type: 'Bank',
      balance: 100,
      icon: 'account_balance',
      color: '#4CAF50',
      isShared: false,
      createdAt: date,
    );
    final sourceId = await accountDao.insertAccount(source);
    final destinationId = await accountDao.insertAccount(
      source.copyWith(name: 'Savings', balance: 0),
    );
    final draft = Transaction(
      accountId: sourceId,
      transferToAccountId: destinationId,
      categoryId: 1,
      title: 'Transfer',
      amount: 20,
      type: 'transfer',
      date: date,
      isPrivate: false,
      createdAt: date,
    );
    final id = await transactionDao.insertTransaction(draft);
    final original = draft.copyWith(id: id);

    expect(await transactionDao.updateTransaction(
      original.copyWith(amount: 30), original,
    ), 1);
    await expectLater(
      transactionDao.updateTransaction(original.copyWith(amount: 40), original),
      throwsStateError,
    );
    expect((await accountDao.getAccount(sourceId))!.balance, 70);
    expect((await accountDao.getAccount(destinationId))!.balance, 30);

    expect(await transactionDao.deleteTransaction(original), 1);
    expect(await transactionDao.deleteTransaction(original), 0);
    await transactionDao.bulkDeleteTransactions([original, original]);
    expect((await accountDao.getAccount(sourceId))!.balance, 100);
    expect((await accountDao.getAccount(destinationId))!.balance, 0);
    expect(await transactionDao.getTransaction(id), isNull);
  });

  test('invalid JSON restore rolls back rows already replaced', () async {
    final accountId = await accountDao.insertAccount(Account(
      name: 'Checking',
      type: 'Bank',
      balance: 100,
      icon: 'account_balance',
      color: '#4CAF50',
      isShared: false,
      createdAt: DateTime(2026, 1, 1),
    ));
    final before = await db.query('account');
    final badBackup = jsonEncode({
      'account': [before.single, {...before.single, 'id': accountId + 1, 'name': null}],
    });

    await expectLater(
      BackupService.instance.importDataFromJson(badBackup),
      throwsA(isA<DatabaseException>()),
    );
    expect(await db.query('account'), before);
  });

  test('CSV restores both transfer legs and retains the ledger on invalid input',
      () async {
    const header = 'Date,Title,Amount,Type,Category,Account,Note,Recurrence,'
        'Recurrence End Date,Is Private,Destination Account,Deduct from Budget';
    const row = '2026-01-01,Transfer,20,transfer,Other,Checking,,none,,no,Savings,no';

    final service = BackupService.instance;
    await service.importDataFromCsv('$header\r\n$row');
    final entry = (await transactionDao.getAllTransactions()).single;
    final accounts = await accountDao.getAllAccounts();
    expect(accounts.firstWhere((account) => account.id == entry.accountId).balance, -20);
    expect(accounts.firstWhere((account) => account.id == entry.transferToAccountId).balance, 20);
    expect(entry.isBudgetIncluded, isFalse);

    final csv = await service.exportDataToCsv();
    await service.importDataFromCsv(csv);
    final before = await db.query('transaction_log');
    const badRow = 'invalid,Coffee,5,expense,Other,Checking,,none,,no,,yes';
    await expectLater(
      service.importDataFromCsv('$header\r\n$row\r\n$badRow'),
      throwsFormatException,
    );
    expect(await db.query('transaction_log'), before);
  });

  test('v14 recurring transfers stay anchored and post once across refreshes',
      () async {
    await AppDatabase.instance.upgradeDatabase(db, 14, 15);
    final january = DateTime(2025, 1, 31);
    final account = Account(
      name: 'Checking',
      type: 'Bank',
      balance: 100,
      icon: 'account_balance',
      color: '#4CAF50',
      isShared: false,
      createdAt: january,
    );
    final from = await accountDao.insertAccount(account);
    final to = await accountDao.insertAccount(
      account.copyWith(name: 'Savings', balance: 0),
    );
    final draft = Transaction(
      accountId: from,
      transferToAccountId: to,
      categoryId: 1,
      title: 'Monthly savings',
      type: 'transfer',
      amount: 10,
      date: january,
      recurrence: 'monthly',
      isBudgetIncluded: false,
      isPrivate: true,
      createdAt: january,
    );
    final templateId = await transactionDao.insertTransaction(draft);
    final template = draft.copyWith(id: templateId);
    final february = DateTime(2025, 2, 28);
    final march = DateTime(2025, 3, 31);
    expect(RecurrenceEngine.datesThrough(template, march), [february, march]);
    final forecast = RecurrenceEngine.projectFutureInstances(
      [template],
      now: january,
    ).firstWhere((tx) => tx.date == february);
    expect(forecast.transferToAccountId, to);
    expect(forecast.isBudgetIncluded, isFalse);

    // Same account, category, amount and date as the first occurrence.
    await transactionDao.insertTransaction(draft.copyWith(
      title: 'Manual transfer',
      date: february,
      recurrence: 'none',
    ));
    expect(await Future.wait([
      transactionDao.postDueRecurrences(march),
      transactionDao.postDueRecurrences(march),
    ]), [true, false]);
    final posted = await db.query(
      'transaction_log',
      where: 'recurrence_template_id = ?',
      whereArgs: [templateId],
      orderBy: 'date',
    );
    expect(posted.map((row) => row['date']), ['2025-02-28', '2025-03-31']);
    expect(posted.every((row) => row['is_budget_included'] == 0), isTrue);
    expect((await accountDao.getAccount(from))!.balance, 60);
    expect((await accountDao.getAccount(to))!.balance, 40);
  });

  test('restore keeps the device PIN profile and remaps imported diagnostics',
      () async {
    await db.execute("""
      CREATE TABLE user_profile (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        preferred_currency TEXT NOT NULL,
        pin_hash TEXT NOT NULL,
        biometric_enabled INTEGER NOT NULL,
        theme_preference TEXT NOT NULL,
        reminder_enabled INTEGER NOT NULL,
        reminder_time TEXT NOT NULL
      )
    """);
    await db.execute("""
      CREATE TABLE diagnostic_profile (
        id INTEGER PRIMARY KEY,
        user_profile_id INTEGER NOT NULL
      )
    """);
    final local = UserProfile(
      id: 7,
      name: 'Current device',
      preferredCurrency: 'USD',
      pinHash: 'local-verifier',
      biometricEnabled: false,
      themePreference: 'dark',
      reminderEnabled: false,
      reminderTime: '20:00',
    );
    final profiles = UserProfileDao();

    await expectLater(
      profiles.insertProfile(local, saveCredentials: (_) async {
        throw StateError('Secure storage unavailable');
      }),
      throwsException,
    );
    expect(await profiles.getAllProfiles(), isEmpty);

    await profiles.insertProfile(local, saveCredentials: (_) async {});
    await BackupService.instance.importDataFromJson(jsonEncode({
      'user_profile': [
        local.copyWith(id: 1, name: 'Previous device', pinHash: 'old-verifier')
            .toMap(),
      ],
      'diagnostic_profile': [
        {'id': 1, 'user_profile_id': 1},
      ],
    }));
    expect((await profiles.getAllProfiles()).single.toMap(), local.toMap());
    expect((await db.query('diagnostic_profile')).single['user_profile_id'], 7);
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
