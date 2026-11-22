import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart' show DatabaseExecutor;

import '../database.dart';
import '../../analytics/recurrence_engine.dart';
import '../../../models/transaction.dart';

class TransactionDao {
  final AppDatabase _dbProvider = AppDatabase.instance;

  Future<int> insertTransaction(Transaction tx) async {
    final db = await _dbProvider.database;
    return db.transaction((txn) async {
      final id = await txn.insert('transaction_log', tx.toMap());
      await _adjustBalances(txn, tx, 1);
      return id;
    });
  }

  Future<bool> postDueRecurrences(DateTime today) async {
    final db = await _dbProvider.database;
    return db.transaction((txn) async {
      final templates = await txn.query(
        'transaction_log',
        where: "recurrence != 'none' AND parent_id IS NULL",
      );
      var posted = false;
      for (final row in templates) {
        final template = Transaction.fromMap(row);
        final templateId = template.id!;
        final postedRows = await txn.query(
          'transaction_log',
          columns: ['recurrence_scheduled_date'],
          where: 'recurrence_template_id = ?',
          whereArgs: [templateId],
        );
        final postedDates = postedRows
            .map((row) => row['recurrence_scheduled_date'] as String)
            .toSet();

        // Older builds recorded an identifying note, but used a drifting
        // schedule. Preserve their history through the last known posting.
        final legacyNote = 'Auto-posted recurring instance of "${template.title}".';
        final legacyRows = await txn.query(
          'transaction_log',
          columns: ['date'],
          where: "recurrence_template_id IS NULL AND recurrence = 'none' "
              'AND parent_id IS NULL AND note = ? AND account_id = ? '
              'AND category_id = ? AND amount_minor = ? AND type = ? AND date >= ?',
          whereArgs: [
            legacyNote, template.accountId, template.categoryId,
            template.amountMinorUnits, template.type, row['date'],
          ],
          orderBy: 'date DESC',
          limit: 1,
        );
        final legacyThrough =
            legacyRows.isEmpty ? null : legacyRows.single['date'] as String;

        for (final date in RecurrenceEngine.datesThrough(template, today)) {
          final scheduledDate = date.toIso8601String().substring(0, 10);
          if (postedDates.contains(scheduledDate) ||
              (legacyThrough != null && scheduledDate.compareTo(legacyThrough) <= 0)) {
            continue;
          }

          final entry = template.copyWith(
            id: null,
            date: date,
            note: template.note ?? legacyNote,
            recurrence: 'none',
            recurrenceEndDate: null,
            createdAt: today,
          );
          await txn.insert('transaction_log', {
            ...entry.toMap(),
            'recurrence_template_id': templateId,
            'recurrence_scheduled_date': scheduledDate,
          });
          await _adjustBalances(txn, entry, 1);
          posted = true;
        }
      }
      return posted;
    });
  }

  Future<int> updateTransaction(Transaction newTx, Transaction oldTx) async {
    if (newTx.id == null || newTx.id != oldTx.id) {
      throw ArgumentError('An edit must reference the same saved transaction.');
    }

    final db = await _dbProvider.database;
    return db.transaction((txn) async {
      final saved = await _getTransaction(txn, newTx.id!);
      if (saved == null) return 0;

      // Compare the persisted representation so date-only fields and rounded
      // amounts are compared with the same precision as SQLite.
      if (!mapEquals(saved.toMap(), Transaction.fromMap(oldTx.toMap()).toMap())) {
        throw StateError('This transaction changed. Reopen it before editing.');
      }

      final count = await txn.update(
        'transaction_log',
        newTx.toMap(),
        where: 'id = ?',
        whereArgs: [newTx.id],
      );
      if (count != 1) throw StateError('The transaction could not be updated.');
      await _adjustBalances(txn, saved, -1);
      await _adjustBalances(txn, newTx, 1);
      return count;
    });
  }

  Future<int> deleteTransaction(Transaction tx) async {
    final id = tx.id;
    if (id == null) return 0;

    final db = await _dbProvider.database;
    return db.transaction((txn) => _deleteTransaction(txn, id));
  }

  Future<int> _deleteTransaction(DatabaseExecutor db, int id) async {
    final saved = await _getTransaction(db, id);
    if (saved == null) return 0;

    await db.delete('transaction_log', where: 'parent_id = ?', whereArgs: [id]);
    final count = await db.delete('transaction_log', where: 'id = ?', whereArgs: [id]);
    if (count != 1) throw StateError('The transaction could not be deleted.');
    await _adjustBalances(db, saved, -1);
    return count;
  }

  Future<void> _adjustBalances(
    DatabaseExecutor db,
    Transaction tx,
    int direction,
  ) async {
    // Split rows allocate the parent's amount across categories.
    if (tx.parentId != null) return;

    final amount = tx.amountMinorUnits * direction;
    switch (tx.type) {
      case 'income':
        await _adjustAccount(db, tx.accountId, amount);
        break;
      case 'expense':
      case 'transfer':
        await _adjustAccount(db, tx.accountId, -amount);
        final destination = tx.transferToAccountId ??
            (tx.type == 'expense'
                ? _parseCreditCardTargetAccountId(tx.note)
                : _parseDestAccountId(tx.note));
        if (destination != null) {
          await _adjustAccount(db, destination, amount);
        }
        break;
    }
  }

  Future<void> _adjustAccount(DatabaseExecutor db, int id, int delta) async {
    await db.rawUpdate(
      'UPDATE account SET balance_minor = balance_minor + ?, '
      'balance = (balance_minor + ?) / 100.0 WHERE id = ?',
      [delta, delta, id],
    );
  }

  Future<Transaction?> getTransaction(int id) async {
    final db = await _dbProvider.database;
    return _getTransaction(db, id);
  }

  Future<Transaction?> _getTransaction(DatabaseExecutor db, int id) async {
    final rows = await db.query('transaction_log', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Transaction.fromMap(rows.single);
  }

  Future<List<Transaction>> getAllTransactions() async {
    final db = await _dbProvider.database;
    final result = await db.query('transaction_log', orderBy: 'date DESC, id DESC');
    return result.map<Transaction>((json) => Transaction.fromMap(json)).toList();
  }

  Future<List<Transaction>> getTransactionsForAccount(int accountId) async {
    final db = await _dbProvider.database;
    final result = await db.query(
      'transaction_log',
      where: 'account_id = ?',
      whereArgs: [accountId],
      orderBy: 'date DESC, id DESC',
    );
    return result.map<Transaction>((json) => Transaction.fromMap(json)).toList();
  }

  Future<List<Transaction>> getTransactionsForCategory(int categoryId) async {
    final db = await _dbProvider.database;
    final result = await db.query(
      'transaction_log',
      where: 'category_id = ?',
      whereArgs: [categoryId],
      orderBy: 'date DESC, id DESC',
    );
    return result.map<Transaction>((json) => Transaction.fromMap(json)).toList();
  }

  Future<List<Transaction>> getTransactionsForMonth(String monthStr) async {
    final db = await _dbProvider.database;
    final result = await db.query(
      'transaction_log',
      where: "strftime('%Y-%m', date) = ?",
      whereArgs: [monthStr],
      orderBy: 'date DESC, id DESC',
    );
    return result.map<Transaction>((json) => Transaction.fromMap(json)).toList();
  }

  Future<void> bulkDeleteTransactions(List<Transaction> txs) async {
    final db = await _dbProvider.database;
    await db.transaction((txn) async {
      for (final id in txs.map((tx) => tx.id).whereType<int>().toSet()) {
        await _deleteTransaction(txn, id);
      }
    });
  }

  int? _parseDestAccountId(String? note) {
    if (note == null || note.trim().isEmpty) return null;
    final regExp = RegExp(r'Transfer to target account ID:\s*(\d+)', caseSensitive: false);
    final match = regExp.firstMatch(note);
    if (match != null) {
      return int.tryParse(match.group(1) ?? '');
    }
    return null;
  }

  int? _parseCreditCardTargetAccountId(String? note) {
    if (note == null || note.trim().isEmpty) return null;
    final regExp = RegExp(r'Credit Card payment to account ID:\s*(\d+)', caseSensitive: false);
    final match = regExp.firstMatch(note);
    if (match != null) {
      return int.tryParse(match.group(1) ?? '');
    }
    return null;
  }
}
