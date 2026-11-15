import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;
import 'package:money_manager/core/database/database.dart';
import 'package:money_manager/core/backup/backup_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('FEATURE F08: Backup, Restore, Database Migration & Financial Balance Integrity', () {
    late String tempDir;

    setUp(() async {
      final dir = await Directory.systemTemp.createTemp('f08_test_');
      tempDir = dir.path;
    });

    tearDown(() async {
      try {
        final dir = Directory(tempDir);
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      } catch (_) {}
    });

    test('TEST-014: Opening balances preserved across v12 -> v13 -> v14 migrations without erasure', () async {
      final dbPath = '$tempDir/v12_legacy.db';
      final db = await databaseFactory.openDatabase(dbPath);

      // 1. Create legacy v12 schema
      await db.execute('''
        CREATE TABLE account (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          type TEXT NOT NULL,
          balance REAL NOT NULL DEFAULT 0.0,
          icon TEXT NOT NULL,
          color TEXT NOT NULL,
          is_shared INTEGER NOT NULL DEFAULT 1,
          limit_amount REAL,
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
          subcategory_id INTEGER
        )
      ''');

      await db.execute('''
        CREATE TABLE category (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          icon TEXT NOT NULL,
          color TEXT NOT NULL,
          is_default INTEGER NOT NULL DEFAULT 0,
          type TEXT NOT NULL DEFAULT 'both',
          parent_id INTEGER,
          spending_limit REAL,
          dark_color TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE budget (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          category_id INTEGER NOT NULL,
          month TEXT NOT NULL,
          limit_amount REAL NOT NULL,
          recurrence TEXT NOT NULL DEFAULT 'monthly',
          group_name TEXT
        )
      ''');

      // 2. Insert realistic financial dataset (User scenario from Section 7):
      // Account A — HDFC Savings: Opening ₹50,000, Income ₹10,000, Expense ₹2,500, Outgoing transfer ₹5,000, Incoming transfer ₹2,000 -> Current balance = ₹54,500
      await db.insert('account', {
        'id': 1,
        'name': 'HDFC Savings',
        'type': 'Bank',
        'balance': 54500.0,
        'icon': 'account_balance',
        'color': '#1E88E5',
        'is_shared': 1,
        'created_at': '2026-01-01',
      });

      // Account B — Cash: Opening ₹5,000, Expense ₹500, Incoming transfer ₹5,000 -> Current balance = ₹9,500
      await db.insert('account', {
        'id': 2,
        'name': 'Cash',
        'type': 'Cash',
        'balance': 9500.0,
        'icon': 'payments',
        'color': '#4CAF50',
        'is_shared': 1,
        'created_at': '2026-01-01',
      });

      // Account C — Emergency Fund: Opening ₹15,000, ZERO transactions -> Current balance = ₹15,000
      await db.insert('account', {
        'id': 3,
        'name': 'Emergency Fund',
        'type': 'Savings',
        'balance': 15000.0,
        'icon': 'savings',
        'color': '#FF9800',
        'is_shared': 1,
        'created_at': '2026-01-01',
      });

      // Transactions for Account A
      await db.insert('transaction_log', {
        'account_id': 1,
        'category_id': 1,
        'title': 'Salary',
        'amount': 10000.0,
        'type': 'income',
        'date': '2026-10-01',
        'created_at': '2026-10-01',
      });
      await db.insert('transaction_log', {
        'account_id': 1,
        'category_id': 2,
        'title': 'Groceries',
        'amount': 2500.0,
        'type': 'expense',
        'date': '2026-10-02',
        'created_at': '2026-10-02',
      });
      await db.insert('transaction_log', {
        'account_id': 1,
        'category_id': 3,
        'title': 'ATM Withdrawal to Cash',
        'amount': 5000.0,
        'type': 'transfer',
        'transfer_to_account_id': 2,
        'date': '2026-10-03',
        'created_at': '2026-10-03',
      });
      await db.insert('transaction_log', {
        'account_id': 2,
        'category_id': 1,
        'title': 'Refund Received to Account A',
        'amount': 2000.0,
        'type': 'transfer',
        'transfer_to_account_id': 1,
        'date': '2026-10-04',
        'created_at': '2026-10-04',
      });

      // Transaction for Account B
      await db.insert('transaction_log', {
        'account_id': 2,
        'category_id': 2,
        'title': 'Snacks',
        'amount': 500.0,
        'type': 'expense',
        'date': '2026-10-05',
        'created_at': '2026-10-05',
      });

      await db.setVersion(12);
      await db.close();

      // 3. Re-open through AppDatabase upgrade pipeline (v12 -> v13 -> v14)
      final upgradedDb = await databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 14,
          onUpgrade: AppDatabase.instance.upgradeDatabase,
        ),
      );

      final accounts = await upgradedDb.query('account', orderBy: 'id ASC');
      expect(accounts.length, equals(3));

      // Account A: Expected 54,500.00 (5,450,000 paise)
      expect(accounts[0]['name'], equals('HDFC Savings'));
      expect(accounts[0]['balance_minor'], equals(5450000));
      expect((accounts[0]['balance'] as num).toDouble(), equals(54500.0));
      expect(accounts[0]['initial_balance_minor'], equals(5000000)); // ₹50,000 opening balance preserved!

      // Account B: Expected 9,500.00 (950,000 paise)
      expect(accounts[1]['name'], equals('Cash'));
      expect(accounts[1]['balance_minor'], equals(950000));
      expect((accounts[1]['balance'] as num).toDouble(), equals(9500.0));
      expect(accounts[1]['initial_balance_minor'], equals(5000000)); // ₹5,000 opening balance preserved!

      // Account C: Expected 15,000.00 (1,500,000 paise) — zero transactions!
      expect(accounts[2]['name'], equals('Emergency Fund'));
      expect(accounts[2]['balance_minor'], equals(1500000));
      expect((accounts[2]['balance'] as num).toDouble(), equals(15000.0));
      expect(accounts[2]['initial_balance_minor'], equals(1500000)); // ₹15,000 opening balance NOT reset to 0!

      // Verify audit logs exist
      final auditLogs = await upgradedDb.query('balance_audit_log');
      expect(auditLogs.length, equals(3));
      for (var log in auditLogs) {
        expect(log['reconciliation_status'], equals('EXACT_MATCH'));
      }

      await upgradedDb.close();
    });

    test('TEST-015: Credit card purchases & bill settlement reconciliation preserves limits & liability', () async {
      final dbPath = '$tempDir/cc_reconcile.db';
      final db = await databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 14,
          onCreate: (db, version) async {
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
                is_budget_included INTEGER NOT NULL DEFAULT 1
              )
            ''');
            await db.execute('''
              CREATE TABLE backup_metadata (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL
              )
            ''');
            await db.execute('''
              CREATE TABLE balance_audit_log (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                account_id INTEGER NOT NULL,
                timestamp TEXT NOT NULL,
                event_type TEXT NOT NULL,
                opening_balance_minor INTEGER NOT NULL,
                net_transactions_minor INTEGER NOT NULL,
                calculated_balance_minor INTEGER NOT NULL,
                stored_balance_minor INTEGER NOT NULL,
                reconciliation_status TEXT NOT NULL
              )
            ''');
          },
        ),
      );

      // Bank account with ₹50,000
      await db.insert('account', {
        'id': 1,
        'name': 'Salary Bank',
        'type': 'Bank',
        'balance': 50000.0,
        'balance_minor': 5000000,
        'initial_balance': 50000.0,
        'initial_balance_minor': 5000000,
        'icon': 'account_balance',
        'color': '#1E88E5',
        'is_shared': 1,
        'created_at': '2026-01-01',
      });

      // Credit card with ₹100,000 limit, starting at 0
      await db.insert('account', {
        'id': 2,
        'name': 'HDFC Millennia',
        'type': 'Credit Card',
        'balance': 0.0,
        'balance_minor': 0,
        'initial_balance': 0.0,
        'initial_balance_minor': 0,
        'limit_amount': 100000.0,
        'limit_amount_minor': 10000000,
        'icon': 'credit_card',
        'color': '#E53935',
        'is_shared': 1,
        'created_at': '2026-01-01',
      });

      // 1. Credit card expense: ₹15,000
      await db.insert('transaction_log', {
        'account_id': 2,
        'category_id': 1,
        'title': 'Flight Tickets',
        'amount': 15000.0,
        'amount_minor': 1500000,
        'type': 'expense',
        'date': '2026-10-05',
        'created_at': '2026-10-05',
      });

      // 2. Bill payment from Bank to Credit Card: ₹10,000
      await db.insert('transaction_log', {
        'account_id': 1,
        'category_id': 8,
        'title': 'Credit Card Bill Payment',
        'amount': 10000.0,
        'amount_minor': 1000000,
        'type': 'expense',
        'transfer_to_account_id': 2,
        'date': '2026-10-20',
        'created_at': '2026-10-20',
      });

      // Recalculate
      await AppDatabase.instance.recalculateAllBalances(db);

      final accounts = await db.query('account', orderBy: 'id ASC');
      // Bank: ₹50,000 - ₹10,000 payment = ₹40,000 (4,000,000 paise)
      expect(accounts[0]['balance_minor'], equals(4000000));
      expect((accounts[0]['balance'] as num).toDouble(), equals(40000.0));

      // Credit Card: 0 - ₹15,000 purchase + ₹10,000 payment = -₹5,000 liability (-500,000 paise)
      expect(accounts[1]['balance_minor'], equals(-500000));
      expect((accounts[1]['balance'] as num).toDouble(), equals(-5000.0));

      await db.close();
    });

    test('TEST-016: Backup validation detects valid SQLite, corrupt files, and newer schema versions', () async {
      // 1. Valid SQLite file
      final validPath = '$tempDir/valid.db';
      final validDb = await databaseFactory.openDatabase(
        validPath,
        options: OpenDatabaseOptions(
          version: 14,
          onCreate: (db, v) async {
            await db.execute('CREATE TABLE account (id INTEGER PRIMARY KEY, name TEXT)');
            await db.execute('CREATE TABLE transaction_log (id INTEGER PRIMARY KEY)');
            await db.execute('CREATE TABLE category (id INTEGER PRIMARY KEY)');
          },
        ),
      );
      await validDb.close();

      final validResult = await BackupService.instance.validateBackupFile(File(validPath));
      expect(validResult.isValid, isTrue);
      expect(validResult.schemaVersion, equals(14));

      // 2. Future schema version (v15) rejection
      final futurePath = '$tempDir/future_v15.db';
      final futureDb = await databaseFactory.openDatabase(
        futurePath,
        options: OpenDatabaseOptions(
          version: 15,
          onCreate: (db, v) async {
            await db.execute('CREATE TABLE account (id INTEGER PRIMARY KEY)');
            await db.execute('CREATE TABLE transaction_log (id INTEGER PRIMARY KEY)');
            await db.execute('CREATE TABLE category (id INTEGER PRIMARY KEY)');
          },
        ),
      );
      await futureDb.close();

      final futureResult = await BackupService.instance.validateBackupFile(File(futurePath));
      expect(futureResult.isValid, isFalse);
      expect(futureResult.errorMessage, contains('newer version'));

      // 3. Corrupt file rejection
      final corruptPath = '$tempDir/corrupt.db';
      final corruptFile = File(corruptPath);
      await corruptFile.writeAsString('THIS IS NOT A VALID SQLITE DATABASE FILE HEADER');

      final corruptResult = await BackupService.instance.validateBackupFile(corruptFile);
      expect(corruptResult.isValid, isFalse);
      expect(corruptResult.errorMessage, contains('not a valid SQLite database'));
    });
  });
}
