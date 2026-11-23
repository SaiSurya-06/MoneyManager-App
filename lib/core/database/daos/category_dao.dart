import '../database.dart';
import '../../../models/category.dart';

class CategoryDao {
  static const int otherCategoryId = 8;
  final AppDatabase _dbProvider = AppDatabase.instance;

  Future<int> insertCategory(Category category) async {
    try {
      final db = await _dbProvider.database;
      return await db.insert('category', category.toMap());
    } catch (e) {
      throw Exception('CategoryDao.insertCategory failed: $e');
    }
  }

  Future<int> updateCategory(Category category) async {
    try {
      final db = await _dbProvider.database;
      return await db.update(
        'category',
        category.toMap(),
        where: 'id = ?',
        whereArgs: [category.id],
      );
    } catch (e) {
      throw Exception('CategoryDao.updateCategory failed: $e');
    }
  }

  Future<int> deleteCategory(int id) async {
    final db = await _dbProvider.database;
    return db.transaction((txn) async {
      final rows = await txn.query('category', columns: ['id', 'parent_id'], orderBy: 'id ASC');
      if (!rows.any((row) => row['id'] == id)) return 0;
      final remaining = rows.where((row) => row['id'] != id).toList();
      if (remaining.isEmpty) {
        throw StateError('Cannot delete the only remaining category.');
      }
      final roots = remaining.where((row) => row['parent_id'] == null);
      final fallbackId = (roots.isEmpty ? remaining.first : roots.first)['id'] as int;

      for (final table in ['transaction_log', 'budget', 'transaction_template']) {
        await txn.update(table, {'category_id': fallbackId},
            where: 'category_id = ?', whereArgs: [id]);
      }
      await txn.update('transaction_log', {'subcategory_id': null},
          where: 'subcategory_id = ?', whereArgs: [id]);
      await txn.update('category', {'parent_id': null},
          where: 'parent_id = ?', whereArgs: [id]);
      return txn.delete('category', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<Category?> getCategory(int id) async {
    try {
      final db = await _dbProvider.database;
      final maps = await db.query(
        'category',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (maps.isEmpty) return null;
      return Category.fromMap(maps.first);
    } catch (e) {
      throw Exception('CategoryDao.getCategory failed: $e');
    }
  }

  Future<List<Category>> getAllCategories() async {
    try {
      final db = await _dbProvider.database;
      final result = await db.query('category', orderBy: 'id ASC');
      return result.map((json) => Category.fromMap(json)).toList();
    } catch (e) {
      throw Exception('CategoryDao.getAllCategories failed: $e');
    }
  }
}
