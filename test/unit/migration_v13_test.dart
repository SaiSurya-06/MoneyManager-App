import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('F01: Database Migration v13 Tests', () {
    test('Migration v13 safely converts REAL to integer minor units and preserves data', () async {
      final db = await databaseFactory.openDatabase(inMemoryDatabasePath);

      // 1. Simulate existing v12 schema
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
        CREATE TABLE budget (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          category_id INTEGER NOT NULL,
          month TEXT NOT NULL,
          limit_amount REAL NOT NULL,
          recurrence TEXT NOT NULL DEFAULT 'monthly',
          group_name TEXT
        )
      ''');

      // 2. Insert test records with REAL values
      await db.insert('account', {
        'name': 'HDFC Savings',
        'type': 'Bank',
        'balance': 15250.75,
        'icon': 'account_balance',
        'color': '#1E88E5',
        'is_shared': 1,
        'limit_amount': 50000.00,
        'created_at': '2026-01-01',
      });

      await db.insert('transaction_log', {
        'account_id': 1,
        'category_id': 1,
        'title': 'Salary',
        'amount': 25000.50,
        'type': 'income',
        'date': '2026-10-01',
        'created_at': '2026-10-01',
      });

      await db.insert('transaction_log', {
        'account_id': 1,
        'category_id': 2,
        'title': 'Rent',
        'amount': 9749.75,
        'type': 'expense',
        'date': '2026-10-02',
        'created_at': '2026-10-02',
      });

      await db.insert('budget', {
        'category_id': 2,
        'month': '2026-10',
        'limit_amount': 10000.00,
      });

      // Verify pre-migration counts
      final preAccounts = await db.query('account');
      final preTxs = await db.query('transaction_log');
      final preBudgets = await db.query('budget');

      expect(preAccounts.length, equals(1));
      expect(preTxs.length, equals(2));
      expect(preBudgets.length, equals(1));

      // 3. Perform v13 migration
      // Add columns
      await db.execute("ALTER TABLE account ADD COLUMN balance_minor INTEGER NOT NULL DEFAULT 0");
      await db.execute("ALTER TABLE account ADD COLUMN limit_amount_minor INTEGER");
      await db.execute("ALTER TABLE account ADD COLUMN is_archived INTEGER NOT NULL DEFAULT 0");
      await db.execute("ALTER TABLE account ADD COLUMN archived_at TEXT");
      await db.execute("ALTER TABLE account ADD COLUMN billing_cycle_start_day INTEGER");
      await db.execute("ALTER TABLE account ADD COLUMN statement_due_day INTEGER");
      await db.execute("ALTER TABLE account ADD COLUMN minimum_due REAL");
      await db.execute("ALTER TABLE account ADD COLUMN minimum_due_minor INTEGER");
      await db.execute("ALTER TABLE transaction_log ADD COLUMN amount_minor INTEGER NOT NULL DEFAULT 0");
      await db.execute("ALTER TABLE transaction_log ADD COLUMN is_budget_included INTEGER NOT NULL DEFAULT 1");
      await db.execute("ALTER TABLE budget ADD COLUMN limit_amount_minor INTEGER NOT NULL DEFAULT 0");

      // Update calculations
      await db.execute('''
        UPDATE account SET 
          balance_minor = CAST(ROUND(balance * 100) AS INTEGER),
          limit_amount_minor = CASE WHEN limit_amount IS NOT NULL THEN CAST(ROUND(limit_amount * 100) AS INTEGER) ELSE NULL END,
          is_archived = 0
      ''');

      await db.execute('''
        UPDATE transaction_log SET 
          amount_minor = CAST(ROUND(amount * 100) AS INTEGER),
          is_budget_included = 1
      ''');

      await db.execute('''
        UPDATE budget SET 
          limit_amount_minor = CAST(ROUND(limit_amount * 100) AS INTEGER)
      ''');

      // 4. Verification of migrated records
      final postAccounts = await db.query('account');
      final postTxs = await db.query('transaction_log');
      final postBudgets = await db.query('budget');

      expect(postAccounts.length, equals(1));
      expect(postTxs.length, equals(2));
      expect(postBudgets.length, equals(1));

      // Assert exact minor units
      expect(postAccounts.first['balance_minor'], equals(1525075));
      expect(postAccounts.first['limit_amount_minor'], equals(5000000));
      expect(postAccounts.first['is_archived'], equals(0));

      expect(postTxs[0]['amount_minor'], equals(2500050));
      expect(postTxs[0]['is_budget_included'], equals(1));

      expect(postTxs[1]['amount_minor'], equals(974975));
      expect(postTxs[1]['is_budget_included'], equals(1));

      expect(postBudgets.first['limit_amount_minor'], equals(1000000));

      await db.close();
    });
  });
}
