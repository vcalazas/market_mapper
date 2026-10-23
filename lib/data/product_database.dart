import 'package:sqflite/sqflite.dart';

import 'product.dart';

class ProductDatabase {
  ProductDatabase._();
  static final ProductDatabase instance = ProductDatabase._();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final path = await getDatabasesPath();
    _database = await openDatabase(
      '$path/prateleira.db',
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE products (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            barcode TEXT NOT NULL UNIQUE,
            name TEXT NOT NULL,
            price REAL NOT NULL
          )
        ''');
      },
    );
    return _database!;
  }

  Future<List<Product>> getAll({String query = ''}) async {
    final db = await database;
    final rows = await db.query(
      'products',
      where: query.isEmpty ? null : 'name LIKE ? OR barcode LIKE ?',
      whereArgs: query.isEmpty ? null : ['%$query%', '%$query%'],
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map(Product.fromMap).toList();
  }

  Future<Product?> findByBarcode(String barcode) async {
    final db = await database;
    final rows = await db.query(
      'products',
      where: 'barcode = ?',
      whereArgs: [barcode],
      limit: 1,
    );
    return rows.isEmpty ? null : Product.fromMap(rows.first);
  }

  Future<void> save(Product product) async {
    final db = await database;
    if (product.id == null) {
      await db.insert('products', product.toMap(),
          conflictAlgorithm: ConflictAlgorithm.abort);
    } else {
      await db.update('products', product.toMap(),
          where: 'id = ?', whereArgs: [product.id]);
    }
  }

  Future<void> delete(int id) async {
    final db = await database;
    await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }
}
