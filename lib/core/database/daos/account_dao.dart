import '../database.dart';
import '../../../models/account.dart';
import 'package:sqflite/sqflite.dart';

class AccountDao {
  final AppDatabase _dbProvider = AppDatabase.instance;

  Future<Map<String, dynamic>> _filterToExistingColumns(
    DatabaseExecutor db,
    String table,
    Map<String, dynamic> map,
  ) async {
    try {
      final tableInfo = await db.rawQuery("PRAGMA table_info('$table')");
      if (tableInfo.isEmpty) return map;
      final columnNames = tableInfo.map((c) => c['name'] as String).toSet();
      final filtered = Map<String, dynamic>.from(map);
      filtered.removeWhere((key, _) => !columnNames.contains(key));
      return filtered;
    } catch (_) {
      return map;
    }
  }

  Future<int> insertAccount(Account account) async {
    try {
      final db = await _dbProvider.database;
      final map = account.toMap();
      if (!map.containsKey('initial_balance_minor') || map['initial_balance_minor'] == null) {
        map['initial_balance_minor'] = account.balanceMinorUnits;
        map['initial_balance'] = account.balance;
      }
      final safeMap = await _filterToExistingColumns(db, 'account', map);
      return await db.insert('account', safeMap);
    } catch (e) {
      throw Exception('AccountDao.insertAccount failed: $e');
    }
  }

  Future<int> updateAccount(Account account) async {
    try {
      final db = await _dbProvider.database;
      final safeMap = await _filterToExistingColumns(db, 'account', account.toMap());
      return await db.update(
        'account',
        safeMap,
        where: 'id = ?',
        whereArgs: [account.id],
      );
    } catch (e) {
      throw Exception('AccountDao.updateAccount failed: $e');
    }
  }

  /// Checks the count of transactions associated with this account (both as primary and transfer target).
  Future<int> getTransactionCountForAccount(int accountId) async {
    try {
      final db = await _dbProvider.database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) FROM transaction_log WHERE account_id = ? OR transfer_to_account_id = ?',
        [accountId, accountId],
      );
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      throw Exception('AccountDao.getTransactionCountForAccount failed: $e');
    }
  }

  /// Safe deletion: Throws [StateError] if the account has any associated transactions.
  Future<int> deleteAccount(int id) async {
    final txCount = await getTransactionCountForAccount(id);
    if (txCount > 0) {
      throw StateError('Cannot permanently delete account with $txCount associated transactions. Archive the account instead to protect historical records.');
    }
    try {
      final db = await _dbProvider.database;
      return await db.delete(
        'account',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw Exception('AccountDao.deleteAccount failed: $e');
    }
  }

  /// Archives an account, preserving its records and balance while hiding it from transaction entry by default.
  Future<int> archiveAccount(int id) async {
    try {
      final db = await _dbProvider.database;
      return await db.update(
        'account',
        {
          'is_archived': 1,
          'archived_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw Exception('AccountDao.archiveAccount failed: $e');
    }
  }

  /// Restores an archived account back to active status.
  Future<int> restoreAccount(int id) async {
    try {
      final db = await _dbProvider.database;
      return await db.update(
        'account',
        {
          'is_archived': 0,
          'archived_at': null,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw Exception('AccountDao.restoreAccount failed: $e');
    }
  }

  Future<Account?> getAccount(int id) async {
    try {
      final db = await _dbProvider.database;
      final maps = await db.query(
        'account',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (maps.isEmpty) return null;
      return Account.fromMap(maps.first);
    } catch (e) {
      throw Exception('AccountDao.getAccount failed: $e');
    }
  }

  Future<List<Account>> getAllAccounts({bool includeArchived = true}) async {
    try {
      final db = await _dbProvider.database;
      final result = await db.query(
        'account',
        where: includeArchived ? null : 'is_archived = 0',
        orderBy: 'CASE WHEN is_archived = 0 AND display_order IS NOT NULL '
            'THEN 0 ELSE 1 END, '
            'CASE WHEN is_archived = 0 THEN display_order END, id',
      );
      return result.map((json) => Account.fromMap(json)).toList();
    } catch (e) {
      throw Exception('AccountDao.getAllAccounts failed: $e');
    }
  }

  Future<void> saveActiveAccountOrder(List<int> ids) async {
    final db = await _dbProvider.database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'account',
        columns: ['id'],
        where: 'is_archived = 0',
      );
      final activeIds = rows.map((row) => row['id'] as int).toSet();
      if (ids.length != activeIds.length ||
          ids.toSet().length != ids.length ||
          !activeIds.containsAll(ids)) {
        throw StateError('The active accounts changed. Open Reorder again.');
      }
      final batch = txn.batch();
      for (var index = 0; index < ids.length; index++) {
        batch.update('account', {'display_order': index},
            where: 'id = ?', whereArgs: [ids[index]]);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> recalculateAllBalances() async {
    try {
      final db = await _dbProvider.database;
      await _dbProvider.recalculateAllBalances(db);
    } catch (e) {
      throw Exception('AccountDao.recalculateAllBalances failed: $e');
    }
  }

  Future<int> updateBalance(int accountId, double newBalance) async {
    try {
      final db = await _dbProvider.database;
      final minor = (newBalance * 100).round();
      return await db.rawUpdate(
        'UPDATE account SET balance = ?, balance_minor = ? WHERE id = ?',
        [newBalance, minor, accountId],
      );
    } catch (e) {
      throw Exception('AccountDao.updateBalance failed: $e');
    }
  }
}
