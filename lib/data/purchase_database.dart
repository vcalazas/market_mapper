import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'product.dart';
import 'product_database.dart';

class PurchaseEntry {
  const PurchaseEntry({required this.product, required this.quantity});

  final Product product;
  final int quantity;

  double get subtotal => product.price * quantity;
}

class PurchaseSummary {
  const PurchaseSummary({
    required this.id,
    required this.createdAt,
    required this.total,
    required this.itemCount,
  });

  final int id;
  final DateTime createdAt;
  final double total;
  final int itemCount;
}

class PurchaseDetails extends PurchaseSummary {
  const PurchaseDetails({
    required super.id,
    required super.createdAt,
    required super.total,
    required super.itemCount,
    required this.items,
  });

  final List<PurchaseEntry> items;
}

class PurchaseDatabase {
  PurchaseDatabase._();
  static final PurchaseDatabase instance = PurchaseDatabase._();

  Future<int> savePurchase(List<PurchaseEntry> entries) async {
    if (entries.isEmpty) throw ArgumentError('A compra precisa ter itens.');
    final db = await ProductDatabase.instance.database;
    final total = entries.fold<double>(0, (sum, entry) => sum + entry.subtotal);

    return db.transaction((txn) async {
      final purchaseId = await txn.insert('purchases', {
        'created_at': DateTime.now().toIso8601String(),
        'total': total,
      });
      for (final entry in entries) {
        await txn.insert('purchase_items', {
          'purchase_id': purchaseId,
          'product_id': entry.product.id,
          'barcode': entry.product.barcode,
          'name': entry.product.name,
          'unit_price': entry.product.price,
          'quantity': entry.quantity,
          'subtotal': entry.subtotal,
        });
      }
      return purchaseId;
    });
  }

  Future<List<PurchaseSummary>> getAllPurchases() async {
    final db = await ProductDatabase.instance.database;
    final rows = await db.rawQuery('''
      SELECT p.id, p.created_at, p.total, COUNT(i.id) AS item_count
      FROM purchases p
      LEFT JOIN purchase_items i ON i.purchase_id = p.id
      GROUP BY p.id
      ORDER BY p.created_at DESC, p.id DESC
    ''');
    return rows
        .map((row) => PurchaseSummary(
              id: row['id'] as int,
              createdAt: DateTime.parse(row['created_at'] as String),
              total: (row['total'] as num).toDouble(),
              itemCount: (row['item_count'] as num).toInt(),
            ))
        .toList();
  }

  Future<PurchaseDetails?> getPurchase(int id) async {
    final db = await ProductDatabase.instance.database;
    final purchaseRows = await db.query(
      'purchases',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (purchaseRows.isEmpty) return null;

    final itemRows = await db.query(
      'purchase_items',
      where: 'purchase_id = ?',
      whereArgs: [id],
      orderBy: 'id ASC',
    );
    final row = purchaseRows.first;
    final items = itemRows.map((item) {
      final rawProductId = item['product_id'];
      return PurchaseEntry(
        product: Product(
          id: rawProductId as int?,
          barcode: item['barcode'] as String,
          name: item['name'] as String,
          price: (item['unit_price'] as num).toDouble(),
        ),
        quantity: (item['quantity'] as num).toInt(),
      );
    }).toList();

    return PurchaseDetails(
      id: row['id'] as int,
      createdAt: DateTime.parse(row['created_at'] as String),
      total: (row['total'] as num).toDouble(),
      itemCount: items.length,
      items: items,
    );
  }

  Future<String> exportJson() async {
    final summaries = await getAllPurchases();
    final purchases = <Map<String, Object?>>[];
    for (final summary in summaries) {
      final details = await getPurchase(summary.id);
      if (details == null) continue;
      purchases.add({
        'id': details.id,
        'createdAt': details.createdAt.toIso8601String(),
        'total': details.total,
        'items': details.items
            .map((entry) => {
                  'barcode': entry.product.barcode,
                  'name': entry.product.name,
                  'unitPrice': entry.product.price,
                  'quantity': entry.quantity,
                  'subtotal': entry.subtotal,
                })
            .toList(),
      });
    }
    return const JsonEncoder.withIndent('  ').convert({
      'format': 'prateleira.purchases',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'purchases': purchases,
    });
  }

  Future<int> importJson(String source) async {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic> ||
        decoded['format'] != 'prateleira.purchases' ||
        decoded['version'] != 1 ||
        decoded['purchases'] is! List) {
      throw const FormatException('O arquivo não é uma exportação válida de compras.');
    }

    final purchases = (decoded['purchases'] as List)
        .map<_ImportedPurchase>(_parseImportedPurchase)
        .toList();
    if (purchases.isEmpty) return 0;

    final db = await ProductDatabase.instance.database;
    return db.transaction((txn) async {
      var importedCount = 0;
      for (final purchase in purchases) {
        if (await _alreadyImported(txn, purchase)) continue;
        final id = await txn.insert('purchases', {
          'created_at': purchase.createdAt.toIso8601String(),
          'total': purchase.total,
        });
        for (final entry in purchase.items) {
          await txn.insert('purchase_items', {
            'purchase_id': id,
            'product_id': null,
            'barcode': entry.product.barcode,
            'name': entry.product.name,
            'unit_price': entry.product.price,
            'quantity': entry.quantity,
            'subtotal': entry.subtotal,
          });
        }
        importedCount++;
      }
      return importedCount;
    });
  }

  Future<bool> _alreadyImported(
    Transaction transaction,
    _ImportedPurchase purchase,
  ) async {
    final rows = await transaction.query(
      'purchases',
      columns: ['id'],
      where: 'created_at = ? AND total = ?',
      whereArgs: [purchase.createdAt.toIso8601String(), purchase.total],
    );
    for (final row in rows) {
      final existingItems = await transaction.query(
        'purchase_items',
        where: 'purchase_id = ?',
        whereArgs: [row['id']],
        orderBy: 'id ASC',
      );
      if (existingItems.length != purchase.items.length) continue;
      var same = true;
      for (var index = 0; index < existingItems.length; index++) {
        final existing = existingItems[index];
        final incoming = purchase.items[index];
        if (existing['barcode'] != incoming.product.barcode ||
            existing['name'] != incoming.product.name ||
            (existing['unit_price'] as num).toDouble() != incoming.product.price ||
            (existing['quantity'] as num).toInt() != incoming.quantity) {
          same = false;
          break;
        }
      }
      if (same) return true;
    }
    return false;
  }

  _ImportedPurchase _parseImportedPurchase(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Uma compra no arquivo está inválida.');
    }
    final createdAt = DateTime.tryParse(value['createdAt'] as String? ?? '');
    final rawItems = value['items'];
    if (createdAt == null || rawItems is! List || rawItems.isEmpty) {
      throw const FormatException('Uma compra não tem data ou itens válidos.');
    }

    final items = rawItems.map<PurchaseEntry>((rawItem) {
      if (rawItem is! Map<String, dynamic>) {
        throw const FormatException('Um item de compra está inválido.');
      }
      final barcode = rawItem['barcode'];
      final name = rawItem['name'];
      final rawPrice = rawItem['unitPrice'];
      final rawQuantity = rawItem['quantity'];
      if (barcode is! String || name is! String || barcode.trim().isEmpty ||
          name.trim().isEmpty || rawPrice is! num || rawQuantity is! int ||
          rawPrice < 0 || rawQuantity < 1) {
        throw const FormatException('Um item de compra tem dados inválidos.');
      }
      return PurchaseEntry(
        product: Product(
          barcode: barcode,
          name: name,
          price: rawPrice.toDouble(),
        ),
        quantity: rawQuantity,
      );
    }).toList();
    final calculatedTotal = items.fold<double>(
      0,
      (sum, entry) => sum + entry.subtotal,
    );
    return _ImportedPurchase(
      createdAt: createdAt,
      items: items,
      total: calculatedTotal,
    );
  }
}

class _ImportedPurchase {
  const _ImportedPurchase({
    required this.createdAt,
    required this.items,
    required this.total,
  });

  final DateTime createdAt;
  final List<PurchaseEntry> items;
  final double total;
}
