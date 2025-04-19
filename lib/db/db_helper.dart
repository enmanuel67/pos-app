import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/product.dart';
import '../models/supplier.dart';
import '../models/client.dart';
import '../models/sale.dart';
import '../models/sale_item.dart';

class DBHelper {
  static Database? _db;

  static Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await initDB();
    return _db!;
  }

  static Future<Database> initDB() async {
    final path = join(await getDatabasesPath(), 'pos.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE products (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            barcode TEXT,
            description TEXT,
            price REAL,
            quantity INTEGER,
            supplierId INTEGER,
            FOREIGN KEY (supplierId) REFERENCES suppliers(id)
          )
        ''');

        await db.execute('''
          CREATE TABLE suppliers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            phone TEXT,
            description TEXT,
            address TEXT,
            email TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE clients (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            lastName TEXT,
            phone TEXT,
            address TEXT,
            email TEXT,
            hasCredit INTEGER,
            creditLimit REAL,
            credit REAL,
            creditAvailable REAL
          )
        ''');

        await db.execute('''
          CREATE TABLE sales (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT,
            total REAL,
            clientPhone TEXT,
            isCredit INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE sale_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            sale_id INTEGER,
            product_id INTEGER,
            quantity INTEGER,
            subtotal REAL,
            FOREIGN KEY (sale_id) REFERENCES sales(id)
          )
        ''');
      },
    );
  }

  static Future<void> deleteDatabaseFile() async {
    final path = join(await getDatabasesPath(), 'pos.db');
    await deleteDatabase(path);
  }

  // ─────────────── SUPPLIERS ───────────────
  static Future<int> insertSupplier(Supplier supplier) async {
    final dbClient = await db;
    return await dbClient.insert('suppliers', supplier.toMap());
  }

  static Future<List<Supplier>> getSuppliers() async {
    final dbClient = await db;
    final result = await dbClient.query('suppliers');
    return result.map((e) => Supplier.fromMap(e)).toList();
  }

  static Future<int> updateSupplier(Supplier supplier) async {
    final dbClient = await db;
    return await dbClient.update('suppliers', supplier.toMap(), where: 'id = ?', whereArgs: [supplier.id]);
  }

  static Future<void> deleteSupplier(int id) async {
    final dbClient = await db;
    await dbClient.delete('suppliers', where: 'id = ?', whereArgs: [id]);
  }

  static Future<bool> supplierHasProducts(int supplierId) async {
    final dbClient = await db;
    final result = await dbClient.query('products', where: 'supplierId = ?', whereArgs: [supplierId], limit: 1);
    return result.isNotEmpty;
  }

  // ─────────────── PRODUCTS ───────────────
  static Future<List<Product>> getProducts() async {
    final dbClient = await db;
    final maps = await dbClient.query('products');
    return maps.map((e) => Product.fromMap(e)).toList();
  }

  static Future<int> insertProduct(Product product) async {
    final dbClient = await db;
    return await dbClient.insert('products', product.toMap());
  }

  static Future<int> updateProduct(Product product) async {
    final dbClient = await db;
    return await dbClient.update('products', product.toMap(), where: 'id = ?', whereArgs: [product.id]);
  }

  static Future<void> deleteProduct(int id) async {
    final dbClient = await db;
    await dbClient.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> reduceProductStock(int productId, int quantity) async {
  final dbClient = await db;
  final result = await dbClient.query('products', where: 'id = ?', whereArgs: [productId]);

  if (result.isNotEmpty) {
    final currentQty = result.first['quantity'] as int;
    final newQty = currentQty - quantity;

    await dbClient.update(
      'products',
      {'quantity': newQty},
      where: 'id = ?',
      whereArgs: [productId],
    );

    // Verificación de stock bajo
    if (newQty <= 5) {
      // Aquí puedes activar un SnackBar, notificación, o alerta
      print('⚠ Producto ID $productId tiene bajo inventario ($newQty unidades)');
    }
  }
}

  // ─────────────── CLIENTS ───────────────
  static Future<int> insertClient(Client client) async {
    final dbClient = await db;
    return await dbClient.insert('clients', client.toMap());
  }

  static Future<List<Client>> getClients() async {
    final dbClient = await db;
    final result = await dbClient.query('clients');
    return result.map((e) => Client.fromMap(e)).toList();
  }

  static Future<int> updateClient(Client client) async {
    final dbClient = await db;
    return await dbClient.update('clients', client.toMap(), where: 'id = ?', whereArgs: [client.id]);
  }

  static Future<int> deleteClient(int id) async {
    final dbClient = await db;
    return await dbClient.delete('clients', where: 'id = ?', whereArgs: [id]);
  }

  static Future<Client?> getClientByPhone(String phone) async {
    final dbClient = await db;
    final result = await dbClient.query('clients', where: 'phone = ?', whereArgs: [phone]);
    if (result.isNotEmpty) {
      return Client.fromMap(result.first);
    }
    return null;
  }

  static Future<void> updateClientCredit(String phone, double newCredit, double newAvailable) async {
    final dbClient = await db;
    await dbClient.update('clients', {
      'credit': newCredit,
      'creditAvailable': newAvailable,
    }, where: 'phone = ?', whereArgs: [phone]);
  }

  static Future<void> updateClientCreditAvailable(String phone, double newAvailable) async {
    final dbClient = await db;
    await dbClient.update('clients', {'creditAvailable': newAvailable}, where: 'phone = ?', whereArgs: [phone]);
  }

  static Future<void> applyCreditPurchase(String phone, double amount) async {
    final client = await getClientByPhone(phone);
    if (client != null && client.creditAvailable >= amount) {
      await updateClientCredit(phone, client.credit + amount, client.creditAvailable - amount);
    } else {
      throw Exception('Crédito insuficiente');
    }
  }

  static Future<void> registerClientPayment(String phone, double amount) async {
    final client = await getClientByPhone(phone);
    if (client != null) {
      final newCredit = (client.credit - amount).clamp(0.0, client.creditLimit);
      final newAvailable = (client.creditAvailable + amount).clamp(0.0, client.creditLimit);
      await updateClientCredit(phone, newCredit, newAvailable);
    }
  }

  static Future<void> updateClientDebt(String phone, double newDebt) async {
    final dbClient = await db;
    await dbClient.update('clients', {'credit': newDebt}, where: 'phone = ?', whereArgs: [phone]);
  }

  static Future<List<Sale>> getCreditSalesByClient(String phone) async {
    final dbClient = await db;
    final result = await dbClient.query('sales', where: 'clientPhone = ? AND isCredit = 1', whereArgs: [phone]);
    return result.map((e) => Sale.fromMap(e)).toList();
  }

  static Future<void> markSaleAsPaid(int saleId, double paymentAmount) async {
    final dbClient = await db;
    final result = await dbClient.query('sales', where: 'id = ?', whereArgs: [saleId], limit: 1);
    if (result.isEmpty) return;

    final currentTotal = result.first['total'] as double;
    final newTotal = currentTotal - paymentAmount;

    if (newTotal <= 0) {
      await dbClient.delete('sales', where: 'id = ?', whereArgs: [saleId]);
    } else {
      await dbClient.update('sales', {'total': newTotal}, where: 'id = ?', whereArgs: [saleId]);
    }
  }

  // ─────────────── SALES ───────────────
  static Future<int> insertSale(Sale sale) async {
    final dbClient = await db;
    return await dbClient.insert('sales', sale.toMap());
  }

  static Future<void> insertSaleItems(List<SaleItem> items) async {
    final dbClient = await db;
    for (var item in items) {
      await dbClient.insert('sale_items', item.toMap());
    }
  }
// ───────────────History SALES ───────────────
  static Future<List<Sale>> getAllSales() async {
  final dbClient = await db;
  final result = await dbClient.query('sales');
  return result.map((e) => Sale.fromMap(e)).toList();
}

// Obtener los ítems (productos vendidos) de una venta específica
static Future<List<SaleItem>> getSaleItems(int saleId) async {
  final dbClient = await db;
  final result = await dbClient.query(
    'sale_items',
    where: 'sale_id = ?',
    whereArgs: [saleId],
  );
  return result.map((e) => SaleItem.fromMap(e)).toList();
}

// Obtener los detalles de una venta específica
static Future<Sale?> getSaleById(int id) async {
  final dbClient = await db;
  final result = await dbClient.query('sales', where: 'id = ?', whereArgs: [id]);
  if (result.isNotEmpty) {
    return Sale.fromMap(result.first);
  }
  return null;
}

}
