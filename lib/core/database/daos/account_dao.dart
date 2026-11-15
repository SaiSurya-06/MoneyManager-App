import '../database.dart';
import '../../../models/account.dart';
import 'package:sqflite/sqflite.dart';

class AccountDao {
  final AppDatabase _dbProvider = AppDatabase.instance;

  Future<int> insertAccount(Account account) async {
    try {
      final db = await _dbProvider.database;
      final map = account.toMap();
      if (!map.containsKey('initial_balance_minor') || map['initial_balance_minor'] == null) {
        map['initial_balance_minor'] = account.balanceMinorUnits;
        map['initial_balance'] = account.balance;
      }
      return await db.insert('account', map);
    } catch (e) {
      throw Exception('AccountDao.insertAccount failed: $e');
    }
  }

  Future<int> updateAccount(Account account) async {
    try {
      final db = await _dbProvider.database;
      return await db.update(
        'account',
        account.toMap(),
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
        orderBy: 'id ASC',
      );
      return result.map((json) => Account.fromMap(json)).toList();
    } catch (e) {
      throw Exception('AccountDao.getAllAccounts failed: $e');
    }
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
