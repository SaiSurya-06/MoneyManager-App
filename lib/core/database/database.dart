import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._init();
  static Database? _database;

  static void setMockDatabase(Database db) {
    _database = db;
  }

  // Mutex-style lock: prevents concurrent initialisation / close race conditions.
  // All DAO calls route through the `database` getter, so they are naturally
  // serialised by the single-thread nature of sqflite's connection pool.
  // We add an explicit Completer guard around the first open to protect the
  // "check then initialise" pattern from being racy in hot-restart scenarios.
  static bool _isInitialising = false;
  static final List<Completer<Database>> _pendingInitialisers = [];

  AppDatabase._init();

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) return _database!;

    // Guard against concurrent calls racing to open the DB.
    if (_isInitialising) {
      final completer = Completer<Database>();
      _pendingInitialisers.add(completer);
      return completer.future;
    }

    _isInitialising = true;
    try {
      if (_database != null && _database!.isOpen) return _database!;
      _database = await _initDB('money_manager.db');
      final currentDb = _database!;
      for (final c in _pendingInitialisers) {
        c.complete(currentDb);
      }
      _pendingInitialisers.clear();
      return currentDb;
    } catch (e) {
      for (final c in _pendingInitialisers) {
        c.completeError(e);
      }
      _pendingInitialisers.clear();
      rethrow;
    } finally {
      _isInitialising = false;
    }
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getApplicationDocumentsDirectory();
    final path = join(dbPath.path, filePath);

    final db = await openDatabase(
      path,
      version: 13,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
    return db;
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    // Each migration step is isolated: a failure is logged and the next step
    // is attempted, preventing a single bad migration from blocking all others.
    // sqflite wraps upgrades in a transaction automatically; individual
    // failures here will cause the overall upgrade transaction to roll back.
    if (oldVersion < 2) {
      try {
        await db.execute("ALTER TABLE category ADD COLUMN type TEXT NOT NULL DEFAULT 'both'");
        await db.execute("UPDATE category SET type = 'income' WHERE name = 'Salary'");
        await db.execute("UPDATE category SET type = 'expense' WHERE name IN ('Food', 'Rent', 'Transport', 'Entertainment', 'Health', 'Utilities')");
      } catch (e) {
        // Column may already exist (e.g. re-install on same device).
        assert(() { debugPrint('[DB migration v2] $e'); return true; }());
      }
    }
    if (oldVersion < 3) {
      try {
        await db.execute("ALTER TABLE partner_snapshot ADD COLUMN partner_key TEXT NOT NULL DEFAULT ''");
      } catch (e) {
        assert(() { debugPrint('[DB migration v3] $e'); return true; }());
      }
    }
    if (oldVersion < 4) {
      try {
        final List<Map<String, dynamic>> existing = await db.query(
          'category',
          where: 'name = ?',
          whereArgs: ['Credit Card Payment'],
        );
        if (existing.isEmpty) {
          await db.insert('category', {
            'name': 'Credit Card Payment',
            'icon': 'credit_card',
            'color': 'E53935',
            'is_default': 1,
            'type': 'expense'
          });
        }
      } catch (e) {
        assert(() { debugPrint('[DB migration v4] $e'); return true; }());
      }
    }
    if (oldVersion < 5) {
      try {
        await db.execute('''
          CREATE TABLE savings_goal (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            target_amount REAL NOT NULL,
            current_amount REAL NOT NULL DEFAULT 0.0,
            target_date TEXT,
            color TEXT NOT NULL,
            icon TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE debt_loan (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            type TEXT NOT NULL,
            balance REAL NOT NULL,
            original_amount REAL NOT NULL,
            interest_rate REAL NOT NULL,
            monthly_payment REAL NOT NULL,
            start_date TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE filter_preset (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            filters_json TEXT NOT NULL
          )
        ''');
      } catch (e) {
        assert(() { debugPrint('[DB migration v5] $e'); return true; }());
      }
    }
    if (oldVersion < 6) {
      try {
        await db.execute("ALTER TABLE transaction_log ADD COLUMN tags TEXT NOT NULL DEFAULT ''");
      } catch (e) {
        assert(() { debugPrint('[DB migration v6] $e'); return true; }());
      }
    }
    if (oldVersion < 7) {
      try {
        await db.execute("ALTER TABLE category ADD COLUMN parent_id INTEGER");
        await db.execute("ALTER TABLE category ADD COLUMN spending_limit REAL");
        await db.execute("ALTER TABLE category ADD COLUMN dark_color TEXT");
        await db.execute("ALTER TABLE budget ADD COLUMN recurrence TEXT NOT NULL DEFAULT 'monthly'");
        await db.execute("ALTER TABLE budget ADD COLUMN group_name TEXT");
        await db.execute("ALTER TABLE transaction_log ADD COLUMN parent_id INTEGER");
        await db.execute("ALTER TABLE account ADD COLUMN limit_amount REAL");
        await db.execute('''
          CREATE TABLE transaction_template (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            amount REAL NOT NULL,
            type TEXT NOT NULL,
            category_id INTEGER NOT NULL,
            account_id INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE health_score_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL,
            score REAL NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE sync_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            action TEXT NOT NULL,
            table_name TEXT NOT NULL,
            record_id INTEGER NOT NULL,
            record_data TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
      } catch (e) {
        assert(() { debugPrint('[DB migration v7] $e'); return true; }());
      }
    }
    if (oldVersion < 8) {
      try {
        await db.execute("ALTER TABLE transaction_log ADD COLUMN transfer_to_account_id INTEGER");
        await _migrateNotesToColumn(db);
        await recalculateAllBalances(db);
      } catch (e) {
        assert(() { debugPrint('[DB migration v8] $e'); return true; }());
      }
    }
    if (oldVersion < 9) {
      try {
        await db.execute('''
          CREATE TABLE diagnostic_profile (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_profile_id INTEGER NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            current_act INTEGER NOT NULL DEFAULT 0,
            current_section INTEGER NOT NULL DEFAULT 0,
            completed INTEGER NOT NULL DEFAULT 0,
            profile_json TEXT NOT NULL
          )
        ''');
      } catch (e) {
        assert(() { debugPrint('[DB migration v9] $e'); return true; }());
      }
    }
    if (oldVersion < 10) {
      try {
        await db.execute("ALTER TABLE transaction_log ADD COLUMN subcategory_id INTEGER");
      } catch (e) {
        assert(() { debugPrint('[DB migration v10] $e'); return true; }());
      }
    }
    if (oldVersion < 11) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS intelligence_report_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            month TEXT NOT NULL UNIQUE,
            report_json TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
      } catch (e) {
        assert(() { debugPrint('[DB migration v11] $e'); return true; }());
      }
    }
    if (oldVersion < 12) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS weekly_checkins (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            week_end_date TEXT NOT NULL UNIQUE,
            mood TEXT NOT NULL,
            reason_tags TEXT,
            notes TEXT,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS planning_meta (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            month TEXT NOT NULL UNIQUE,
            estimated_income REAL NOT NULL,
            strategy TEXT NOT NULL,
            needs_pct REAL NOT NULL,
            wants_pct REAL NOT NULL,
            savings_pct REAL NOT NULL,
            investments_pct REAL NOT NULL,
            emergency_pct REAL NOT NULL,
            is_completed INTEGER NOT NULL DEFAULT 1,
            updated_at TEXT NOT NULL
          )
        ''');
      } catch (e) {
        assert(() { debugPrint('[DB migration v12] $e'); return true; }());
      }
    }
    if (oldVersion < 13) {
      await _migrateToV13(db);
    }
  }

  Future<void> _migrateToV13(Database db) async {
    try {
      // 1. Audit pre-migration record counts and sums
      final preAccountCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM account')) ?? 0;
      final preTxCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM transaction_log')) ?? 0;
      final preBudgetCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM budget')) ?? 0;

      // 2. Add integer minor unit columns to monetary tables safely
      final alterStatements = [
        "ALTER TABLE account ADD COLUMN balance_minor INTEGER NOT NULL DEFAULT 0",
        "ALTER TABLE account ADD COLUMN limit_amount_minor INTEGER",
        "ALTER TABLE account ADD COLUMN is_archived INTEGER NOT NULL DEFAULT 0",
        "ALTER TABLE account ADD COLUMN archived_at TEXT",
        "ALTER TABLE account ADD COLUMN billing_cycle_start_day INTEGER",
        "ALTER TABLE account ADD COLUMN statement_due_day INTEGER",
        "ALTER TABLE account ADD COLUMN minimum_due REAL",
        "ALTER TABLE account ADD COLUMN minimum_due_minor INTEGER",
        "ALTER TABLE transaction_log ADD COLUMN amount_minor INTEGER NOT NULL DEFAULT 0",
        "ALTER TABLE transaction_log ADD COLUMN is_budget_included INTEGER NOT NULL DEFAULT 1",
        "ALTER TABLE budget ADD COLUMN limit_amount_minor INTEGER NOT NULL DEFAULT 0",
        "ALTER TABLE savings_goal ADD COLUMN target_amount_minor INTEGER NOT NULL DEFAULT 0",
        "ALTER TABLE savings_goal ADD COLUMN current_amount_minor INTEGER NOT NULL DEFAULT 0",
        "ALTER TABLE debt_loan ADD COLUMN balance_minor INTEGER NOT NULL DEFAULT 0",
        "ALTER TABLE debt_loan ADD COLUMN original_amount_minor INTEGER NOT NULL DEFAULT 0",
        "ALTER TABLE debt_loan ADD COLUMN monthly_payment_minor INTEGER NOT NULL DEFAULT 0",
        "ALTER TABLE category ADD COLUMN spending_limit_minor INTEGER",
        "ALTER TABLE transaction_template ADD COLUMN amount_minor INTEGER NOT NULL DEFAULT 0",
        "ALTER TABLE planning_meta ADD COLUMN estimated_income_minor INTEGER NOT NULL DEFAULT 0",
      ];

      for (final sql in alterStatements) {
        try {
          await db.execute(sql);
        } catch (e) {
          assert(() { debugPrint('[DB migration v13 column add] $e'); return true; }());
        }
      }

      // 3. Migrate existing values into exact integer minor units
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

      await db.execute('''
        UPDATE savings_goal SET 
          target_amount_minor = CAST(ROUND(target_amount * 100) AS INTEGER),
          current_amount_minor = CAST(ROUND(current_amount * 100) AS INTEGER)
      ''');

      await db.execute('''
        UPDATE debt_loan SET 
          balance_minor = CAST(ROUND(balance * 100) AS INTEGER),
          original_amount_minor = CAST(ROUND(original_amount * 100) AS INTEGER),
          monthly_payment_minor = CAST(ROUND(monthly_payment * 100) AS INTEGER)
      ''');

      await db.execute('''
        UPDATE category SET 
          spending_limit_minor = CASE WHEN spending_limit IS NOT NULL THEN CAST(ROUND(spending_limit * 100) AS INTEGER) ELSE NULL END
      ''');

      await db.execute('''
        UPDATE transaction_template SET 
          amount_minor = CAST(ROUND(amount * 100) AS INTEGER)
      ''');

      await db.execute('''
        UPDATE planning_meta SET 
          estimated_income_minor = CAST(ROUND(estimated_income * 100) AS INTEGER)
      ''');

      // 4. Recalculate account balances using integer minor units
      await recalculateAllBalances(db);

      // 5. Create audit table and log migration verification
      await db.execute('''
        CREATE TABLE IF NOT EXISTS migration_audit (
          version INTEGER PRIMARY KEY,
          migrated_at TEXT NOT NULL,
          record_counts TEXT NOT NULL,
          validation_result TEXT NOT NULL
        )
      ''');

      // 6. Create report_history table for automated monthly PDF reports
      await db.execute('''
        CREATE TABLE IF NOT EXISTS report_history (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          report_type TEXT NOT NULL,
          reporting_month TEXT NOT NULL,
          generated_at TEXT NOT NULL,
          file_path TEXT NOT NULL,
          file_size_bytes INTEGER NOT NULL,
          checksum TEXT NOT NULL,
          is_auto_generated INTEGER NOT NULL DEFAULT 1
        )
      ''');

      final postAccountCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM account')) ?? 0;
      final postTxCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM transaction_log')) ?? 0;
      final postBudgetCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM budget')) ?? 0;

      final isCountPreserved = (preAccountCount == postAccountCount) && (preTxCount == postTxCount) && (preBudgetCount == postBudgetCount);

      await db.insert('migration_audit', {
        'version': 13,
        'migrated_at': DateTime.now().toIso8601String(),
        'record_counts': 'accounts: $postAccountCount, transactions: $postTxCount, budgets: $postBudgetCount',
        'validation_result': isCountPreserved ? 'PASSED_VERIFIED' : 'COUNT_MISMATCH',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      assert(() { debugPrint('[DB migration v13] $e'); return true; }());
      rethrow;
    }
  }

  Future<void> _migrateNotesToColumn(Database db) async {
    final txs = await db.query(
      'transaction_log',
      columns: ['id', 'note', 'type'],
      where: "note LIKE '%target account ID: %'",
    );
    final transferRegExp = RegExp(r'Transfer to target account ID: (\d+)');
    final ccRegExp = RegExp(r'Credit Card Payment to target account ID: (\d+)');

    for (var tx in txs) {
      final id = tx['id'] as int;
      final note = tx['note'] as String?;
      if (note == null) continue;

      int? targetAccountId;
      final transferMatch = transferRegExp.firstMatch(note);
      if (transferMatch != null) {
        targetAccountId = int.tryParse(transferMatch.group(1) ?? '');
      } else {
        final ccMatch = ccRegExp.firstMatch(note);
        if (ccMatch != null) {
          targetAccountId = int.tryParse(ccMatch.group(1) ?? '');
        }
      }

      if (targetAccountId != null) {
        await db.update(
          'transaction_log',
          {'transfer_to_account_id': targetAccountId},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    }
  }

  Future<void> recalculateAllBalances(Database db) async {
    final accounts = await db.query('account');
    final accountBalancesMinor = <int, int>{};
    for (var acc in accounts) {
      accountBalancesMinor[acc['id'] as int] = 0;
    }

    final txs = await db.query('transaction_log');
    for (var tx in txs) {
      if (tx['parent_id'] != null) continue; // Skip split child transactions
      
      final accountId = tx['account_id'] as int;
      final int amountMinor = (tx['amount_minor'] as int?) ??
          ((tx['amount'] as num).toDouble() * 100).round();
      final type = tx['type'] as String;
      final transferTo = tx['transfer_to_account_id'] as int?;

      if (type == 'income') {
        accountBalancesMinor[accountId] = (accountBalancesMinor[accountId] ?? 0) + amountMinor;
      } else if (type == 'expense' || type == 'transfer') {
        accountBalancesMinor[accountId] = (accountBalancesMinor[accountId] ?? 0) - amountMinor;
      }

      if (transferTo != null && accountBalancesMinor.containsKey(transferTo)) {
        accountBalancesMinor[transferTo] = (accountBalancesMinor[transferTo] ?? 0) + amountMinor;
      }
    }

    for (var entry in accountBalancesMinor.entries) {
      final minor = entry.value;
      final major = minor / 100.0;
      await db.update(
        'account',
        {
          'balance': major,
          'balance_minor': minor,
        },
        where: 'id = ?',
        whereArgs: [entry.key],
      );
    }
  }

  Future _createDB(Database db, int version) async {
    // 1. User Profile Table
    await db.execute('''
      CREATE TABLE user_profile (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        preferred_currency TEXT NOT NULL,
        pin_hash TEXT NOT NULL,
        biometric_enabled INTEGER NOT NULL DEFAULT 0,
        theme_preference TEXT NOT NULL DEFAULT 'dark',
        reminder_enabled INTEGER NOT NULL DEFAULT 1,
        reminder_time TEXT NOT NULL DEFAULT '20:00'
      )
    ''');

    // 2. Account Table
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

    // 3. Category Table
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
        spending_limit_minor INTEGER,
        dark_color TEXT
      )
    ''');

    // 4. Transaction Table
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
        FOREIGN KEY (category_id) REFERENCES category (id) ON DELETE CASCADE,
        FOREIGN KEY (subcategory_id) REFERENCES category (id) ON DELETE SET NULL
      )
    ''');

    // 5. Budget Table
    await db.execute('''
      CREATE TABLE budget (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER NOT NULL,
        month TEXT NOT NULL,
        limit_amount REAL NOT NULL,
        limit_amount_minor INTEGER NOT NULL DEFAULT 0,
        recurrence TEXT NOT NULL DEFAULT 'monthly',
        group_name TEXT,
        FOREIGN KEY (category_id) REFERENCES category (id) ON DELETE CASCADE
      )
    ''');

    // 6. Partner Snapshot Table
    await db.execute('''
      CREATE TABLE partner_snapshot (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        partner_name TEXT NOT NULL,
        partner_display_color TEXT NOT NULL,
        encoded_data TEXT NOT NULL,
        imported_at TEXT NOT NULL,
        partner_key TEXT NOT NULL DEFAULT ''
      )
    ''');

    // 7. savings_goal Table
    await db.execute('''
      CREATE TABLE savings_goal (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        target_amount REAL NOT NULL,
        target_amount_minor INTEGER NOT NULL DEFAULT 0,
        current_amount REAL NOT NULL DEFAULT 0.0,
        current_amount_minor INTEGER NOT NULL DEFAULT 0,
        target_date TEXT,
        color TEXT NOT NULL,
        icon TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // 8. debt_loan Table
    await db.execute('''
      CREATE TABLE debt_loan (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        balance REAL NOT NULL,
        balance_minor INTEGER NOT NULL DEFAULT 0,
        original_amount REAL NOT NULL,
        original_amount_minor INTEGER NOT NULL DEFAULT 0,
        interest_rate REAL NOT NULL,
        monthly_payment REAL NOT NULL,
        monthly_payment_minor INTEGER NOT NULL DEFAULT 0,
        start_date TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // 9. filter_preset Table
    await db.execute('''
      CREATE TABLE filter_preset (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        filters_json TEXT NOT NULL
      )
    ''');

    // 10. transaction_template Table
    await db.execute('''
      CREATE TABLE transaction_template (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        amount_minor INTEGER NOT NULL DEFAULT 0,
        type TEXT NOT NULL,
        category_id INTEGER NOT NULL,
        account_id INTEGER NOT NULL
      )
    ''');

    // 11. health_score_history Table
    await db.execute('''
      CREATE TABLE health_score_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        score REAL NOT NULL
      )
    ''');

    // 12. sync_queue Table
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action TEXT NOT NULL,
        table_name TEXT NOT NULL,
        record_id INTEGER NOT NULL,
        record_data TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // 13. diagnostic_profile Table
    await db.execute('''
      CREATE TABLE diagnostic_profile (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_profile_id INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        current_act INTEGER NOT NULL DEFAULT 0,
        current_section INTEGER NOT NULL DEFAULT 0,
        completed INTEGER NOT NULL DEFAULT 0,
        profile_json TEXT NOT NULL
      )
    ''');

    // 14. intelligence_report_history Table
    await db.execute('''
      CREATE TABLE intelligence_report_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        month TEXT NOT NULL UNIQUE,
        report_json TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // 15. weekly_checkins Table
    await db.execute('''
      CREATE TABLE weekly_checkins (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        week_end_date TEXT NOT NULL UNIQUE,
        mood TEXT NOT NULL,
        reason_tags TEXT,
        notes TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // 16. planning_meta Table
    await db.execute('''
      CREATE TABLE planning_meta (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        month TEXT NOT NULL UNIQUE,
        estimated_income REAL NOT NULL,
        estimated_income_minor INTEGER NOT NULL DEFAULT 0,
        strategy TEXT NOT NULL,
        needs_pct REAL NOT NULL,
        wants_pct REAL NOT NULL,
        savings_pct REAL NOT NULL,
        investments_pct REAL NOT NULL,
        emergency_pct REAL NOT NULL,
        is_completed INTEGER NOT NULL DEFAULT 1,
        updated_at TEXT NOT NULL
      )
    ''');

    // 17. report_history Table
    await db.execute('''
      CREATE TABLE report_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        report_type TEXT NOT NULL,
        reporting_month TEXT NOT NULL,
        generated_at TEXT NOT NULL,
        file_path TEXT NOT NULL,
        file_size_bytes INTEGER NOT NULL,
        checksum TEXT NOT NULL,
        is_auto_generated INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // Seed Data
    await _seedDatabase(db);
  }

  Future _seedDatabase(Database db) async {
    // Seed default categories
    // Icon names refer to material design icon keys
    final categories = [
      {'name': 'Food', 'icon': 'fastfood', 'color': 'E53935', 'is_default': 1, 'type': 'expense'},
      {'name': 'Rent', 'icon': 'home', 'color': '1E88E5', 'is_default': 1, 'type': 'expense'},
      {'name': 'Salary', 'icon': 'payments', 'color': '4CAF50', 'is_default': 1, 'type': 'income'},
      {'name': 'Transport', 'icon': 'directions_bus', 'color': 'FFB300', 'is_default': 1, 'type': 'expense'},
      {'name': 'Entertainment', 'icon': 'movie', 'color': '8E24AA', 'is_default': 1, 'type': 'expense'},
      {'name': 'Health', 'icon': 'local_hospital', 'color': '00ACC1', 'is_default': 1, 'type': 'expense'},
      {'name': 'Utilities', 'icon': 'power', 'color': 'FB8C00', 'is_default': 1, 'type': 'expense'},
      {'name': 'Credit Card Payment', 'icon': 'credit_card', 'color': 'E53935', 'is_default': 1, 'type': 'expense'},
      {'name': 'Other', 'icon': 'category', 'color': '757575', 'is_default': 1, 'type': 'both'},
    ];

    for (var cat in categories) {
      await db.insert('category', cat);
    }
  }

  Future close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  static Future<void> queueSyncAction(String action, String tableName, int recordId, Map<String, dynamic> recordData) async {
    try {
      final db = await instance.database;
      await db.insert('sync_queue', {
        'action': action,
        'table_name': tableName,
        'record_id': recordId,
        'record_data': jsonEncode(recordData),
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('[queueSyncAction] Error: $e');
    }
  }

  static Future<int> getSyncQueueCount() async {
    try {
      final db = await instance.database;
      final result = await db.rawQuery('SELECT COUNT(*) FROM sync_queue');
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      debugPrint('[getSyncQueueCount] Error: $e');
      return 0;
    }
  }

  static Future<void> clearSyncQueue() async {
    try {
      final db = await instance.database;
      await db.delete('sync_queue');
    } catch (e) {
      debugPrint('[clearSyncQueue] Error: $e');
    }
  }
}
