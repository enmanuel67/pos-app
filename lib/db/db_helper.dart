import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/product.dart';
import '../models/supplier.dart';
import '../models/client.dart';
import '../models/sale.dart';
import '../models/sale_item.dart';
import '../notifiers/inventory_notifier.dart';

class DBHelper {
  static Database? _db;

  static Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await initDB();
    return _db!;
  }

  static Future<Database> database() async {
    return await db;
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
  cost REAL,
  supplierId INTEGER,
  createdAt TEXT, -- 🆕 Fecha de creación
  FOREIGN KEY (supplierId) REFERENCES suppliers(id)
);

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
  total REAL,               -- Monto total original de la factura
  amountDue REAL DEFAULT 0, -- Monto restante por pagar
  clientPhone TEXT,
  isCredit INTEGER,         -- 1 si es a crédito, 0 si es contado
  isPaid INTEGER DEFAULT 0  -- 1 si ya se pagó todo, 0 si aún se debe
)
        ''');

        await db.execute('''
          CREATE TABLE sale_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          sale_id INTEGER,
          product_id INTEGER,
          quantity INTEGER,
          subtotal REAL,
          discount REAL, 
          FOREIGN KEY (sale_id) REFERENCES sales(id)
          )
        ''');
        await db.execute('''
          CREATE TABLE inventory_entries (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  product_id INTEGER,
  supplier_id INTEGER,
  quantity INTEGER,
  cost REAL,
  date TEXT,
  FOREIGN KEY (product_id) REFERENCES products(id),
  FOREIGN KEY (supplier_id) REFERENCES suppliers(id)
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
    return await dbClient.update(
      'suppliers',
      supplier.toMap(),
      where: 'id = ?',
      whereArgs: [supplier.id],
    );
  }

  static Future<void> deleteSupplier(int id) async {
    final dbClient = await db;
    await dbClient.delete('suppliers', where: 'id = ?', whereArgs: [id]);
  }

  static Future<bool> supplierHasProducts(int supplierId) async {
    final dbClient = await db;
    final result = await dbClient.query(
      'products',
      where: 'supplierId = ?',
      whereArgs: [supplierId],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  static Future<List<Product>> getProductsBySupplierAndDate(
    int supplierId,
    DateTime start,
    DateTime end,
  ) async {
    final dbClient = await db;
    final result = await dbClient.query(
      'products',
      where: 'supplierId = ? AND datetime(createdAt) BETWEEN ? AND ?',
      whereArgs: [supplierId, start.toIso8601String(), end.toIso8601String()],
    );

    return result.map((e) => Product.fromMap(e)).toList();
  }

  // ─────────────── PRODUCTS ───────────────
  static Future<Product?> getProductById(int id) async {
    final dbClient = await DBHelper.database();
    final result = await dbClient.query(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isNotEmpty) {
      return Product.fromMap(result.first);
    }
    return null;
  }

  static Future<List<Product>> getProducts() async {
    final dbClient = await db;
    final maps = await dbClient.query('products');
    return maps.map((e) => Product.fromMap(e)).toList();
  }

  static Future<int> insertProduct(Product product) async {
    final dbClient = await db;
    final productMap = product.toMap();
    productMap['createdAt'] = DateTime.now().toIso8601String(); // ← agregado
    return await dbClient.insert('products', productMap);
  }

  static Future<int> updateProduct(Product product) async {
    final dbClient = await db;
    return await dbClient.update(
      'products',
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  static Future<void> deleteProduct(int id) async {
    final dbClient = await db;
    await dbClient.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> reduceProductStock(int productId, int quantity) async {
    final dbClient = await db;
    final result = await dbClient.query(
      'products',
      where: 'id = ?',
      whereArgs: [productId],
    );

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
  print('⚠ Bajo inventario para producto ID $productId ($newQty unidades)');

  // Recalcular el total de productos con bajo inventario
  final lowStock = await dbClient.query(
  'products',
  where: 'quantity <= ?',
  whereArgs: [5],
);
InventoryNotifier.lowStockCount.value = lowStock.length;
}
    }
  }

  static Future<Product?> getProductByBarcode(String barcode) async {
    final dbClient = await db;
    final result = await dbClient.query(
      'products',
      where: 'barcode = ?',
      whereArgs: [barcode],
    );
    if (result.isNotEmpty) {
      return Product.fromMap(result.first);
    }
    return null;
  }

  // ─────────────── actualizar stock ───────────────

  // Sumar cantidad y actualizar costo si aplica
  static Future<void> updateProductStock(
    int productId,
    int addedQuantity,
    double unitCost,
  ) async {
    final dbClient = await db;

    // Obtener el producto actual
    final result = await dbClient.query(
      'products',
      where: 'id = ?',
      whereArgs: [productId],
      limit: 1,
    );

    if (result.isNotEmpty) {
      final current = result.first;
      final currentQty = current['quantity'] as int;

      final newQty = currentQty + addedQuantity;

      // Actualizar el producto (cantidad y costo actual)
      await dbClient.update(
        'products',
        {'quantity': newQty, 'cost': unitCost},
        where: 'id = ?',
        whereArgs: [productId],
      );

      // Registrar la entrada en la tabla de inventario
      await dbClient.insert('inventory_entries', {
        'product_id': productId,
        'supplier_id': current['supplierId'],
        'quantity': addedQuantity,
        'cost': unitCost,
        'date': DateTime.now().toIso8601String(),
      });
    }
  }

  static Future<List<Map<String, dynamic>>> getInventoryEntriesBySupplierAndDate(
    int supplierId, DateTime start, DateTime end) async {
  final dbClient = await db;
  final result = await dbClient.query(
    'inventory_entries',
    where: 'supplier_id = ? AND date BETWEEN ? AND ?',
    whereArgs: [
      supplierId,
      start.toIso8601String(),
      end.add(Duration(days: 1)).toIso8601String(),
    ],
  );
  return result;
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
    return await dbClient.update(
      'clients',
      client.toMap(),
      where: 'id = ?',
      whereArgs: [client.id],
    );
  }

  static Future<int> deleteClient(int id) async {
    final dbClient = await db;
    return await dbClient.delete('clients', where: 'id = ?', whereArgs: [id]);
  }

  static Future<Client?> getClientByPhone(String phone) async {
    final dbClient = await db;
    final result = await dbClient.query(
      'clients',
      where: 'phone = ?',
      whereArgs: [phone],
    );
    if (result.isNotEmpty) {
      return Client.fromMap(result.first);
    }
    return null;
  }

  static Future<void> updateClientCredit(
  String phone,
  double newCredit,
  double newAvailable,
) async {
  final dbClient = await db;
  await dbClient.update(
    'clients',
    {'credit': newCredit, 'creditAvailable': newAvailable},
    where: 'phone = ?',
    whereArgs: [phone],
  );
}

  static Future<void> updateClientCreditAvailable(
    String phone,
    double newAvailable,
  ) async {
    final dbClient = await db;
    await dbClient.update(
      'clients',
      {'creditAvailable': newAvailable},
      where: 'phone = ?',
      whereArgs: [phone],
    );
  }

  static Future<void> applyCreditPurchase(String phone, double amount) async {
    final client = await getClientByPhone(phone);
    if (client != null && client.creditAvailable >= amount) {
      await updateClientCredit(
        phone,
        client.credit + amount,
        client.creditAvailable - amount,
      );
    } else {
      throw Exception('Crédito insuficiente');
    }
  }

  static Future<void> registerClientPayment(String phone, double amount) async {
    final client = await getClientByPhone(phone);
    if (client != null) {
      final newCredit = (client.credit - amount).clamp(0.0, client.creditLimit);
      final newAvailable = (client.creditAvailable + amount).clamp(
        0.0,
        client.creditLimit,
      );
      await updateClientCredit(phone, newCredit, newAvailable);
    }
  }

  static Future<void> updateClientDebt(String phone, double newDebt) async {
    final dbClient = await db;
    await dbClient.update(
      'clients',
      {'credit': newDebt},
      where: 'phone = ?',
      whereArgs: [phone],
    );
  }

  static Future<List<Sale>> getCreditSalesByClient(String phone) async {
  final dbClient = await db;
  final result = await dbClient.query(
    'sales',
    where: 'clientPhone = ? AND isCredit = 1 AND isPaid = 0',
    whereArgs: [phone],
  );
  return result.map((e) => Sale.fromMap(e)).toList();
}


static Future<void> markSaleAsPaid(int saleId, double paymentAmount) async {
  final dbClient = await db;

  final result = await dbClient.query(
    'sales',
    where: 'id = ?',
    whereArgs: [saleId],
    limit: 1,
  );

  if (result.isEmpty) return;

  final sale = Sale.fromMap(result.first);
  final newAmountDue = (sale.amountDue - paymentAmount).clamp(0.0, sale.amountDue);

  await dbClient.update(
    'sales',
    {
      'amountDue': newAmountDue,
      'isPaid': newAmountDue == 0.0 ? 1 : 0,
    },
    where: 'id = ?',
    whereArgs: [saleId],
  );
}

static Future<List<Map<String, dynamic>>> getOverdueCreditInvoices() async {
  final dbClient = await db;
  final today = DateTime.now();
  final fifteenDaysAgo = today.subtract(const Duration(days: 15));

  final result = await dbClient.query(
    'sales',
    where: 'isCredit = 1 AND isPaid = 0 AND date <= ?',
    whereArgs: [fifteenDaysAgo.toIso8601String()],
  );

  List<Map<String, dynamic>> overdueInvoices = [];

  for (var sale in result) {
    final clientPhone = sale['clientPhone'];
    final clientResult = await dbClient.query(
      'clients',
      where: 'phone = ?',
      whereArgs: [clientPhone as String], // ✅ cast corregido aquí
      limit: 1,
    );

    if (clientResult.isNotEmpty) {
      final client = clientResult.first;
      final saleDate = DateTime.parse(sale['date'] as String);
      final daysOverdue = today.difference(saleDate).inDays;

      overdueInvoices.add({
        'clientName': '${client['name']} ${client['lastName']}',
        'amountDue': sale['amountDue'],
        'daysOverdue': daysOverdue,
      });
    }
  }

  return overdueInvoices;
}



static Future<int> getNotificationCount() async {
  int lowStockCount = 0;
  int overdueCount = 0;

  final products = await getProducts();
  lowStockCount = products.where((p) => p.quantity <= 5).length;

  final sales = await getAllSales();
  final today = DateTime.now();
  for (var sale in sales) {
    if (sale.isCredit && !sale.isPaid && sale.clientPhone != null) {
      final date = DateTime.parse(sale.date);
      final difference = today.difference(date).inDays;
      if (difference >= 15) overdueCount++;
    }
  }

  return lowStockCount + overdueCount;
}


  // ─────────────── SALES ───────────────
  static Future<int> insertSale(Sale sale) async {
    final dbClient = await db;
    return await dbClient.insert('sales', sale.toMap());
  }

  static Future<void> insertSaleItems(List<SaleItem> items) async {
    final dbClient = await db;
    for (var item in items) {
      await dbClient.insert(
        'sale_items',
        item.toMap(),
      ); // 👈 Esto debe incluir discount
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
    final result = await dbClient.query(
      'sales',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isNotEmpty) {
      return Sale.fromMap(result.first);
    }
    return null;
  }
}
