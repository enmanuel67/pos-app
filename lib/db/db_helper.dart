import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:pos_app/models/product.dart';
import '../models/supplier.dart';
import '../models/client.dart';
import '../models/sale.dart';
import '../models/sale_item.dart';
import '../models/expense.dart';
import '../models/expense_entry.dart';
import '../notifiers/inventory_notifier.dart';
import 'dart:convert';

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
  business_type TEXT,
  price REAL,
  quantity INTEGER,
  cost REAL,
  supplierId INTEGER,
  is_rentable INTEGER DEFAULT 0,
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

        await db.execute('''
  CREATE TABLE expenses (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT
  )
''');

        await db.execute('''
  CREATE TABLE expense_entries (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    expense_id INTEGER,
    amount REAL,
    date TEXT,
    FOREIGN KEY (expense_id) REFERENCES expenses(id)
  )
''');
        await db.execute('''
    CREATE TABLE payment_history(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      client_phone TEXT,
      amount REAL,
      payment_date TEXT,
      receipt_number TEXT,
      affected_sales TEXT,
      created_at TEXT
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
        print(
          '⚠ Bajo inventario para producto ID $productId ($newQty unidades)',
        );

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

  static Future<List<Map<String, dynamic>>> getProductSalesByBusiness(
    String businessType,
    DateTime start,
    DateTime end,
  ) async {
    final dbClient = await db;

    final result = await dbClient.rawQuery(
      '''
    SELECT 
      p.name AS product_name,
      SUM(si.quantity) AS total_quantity,
      SUM(si.discount * si.quantity) AS total_discount,
      SUM(si.subtotal) AS total_sales,
      SUM(
        (si.subtotal / si.quantity - p.cost) * si.quantity
      ) AS total_gain
    FROM sale_items si
    JOIN sales s ON si.sale_id = s.id
    JOIN products p ON si.product_id = p.id
    WHERE p.business_type = ? AND date(s.date) BETWEEN ? AND ?
    GROUP BY si.product_id
    ORDER BY total_quantity DESC
  ''',
      [
        businessType,
        start.toIso8601String().split('T').first,
        end.toIso8601String().split('T').first,
      ],
    );

    return result;
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

  static Future<List<Map<String, dynamic>>>
  getInventoryEntriesBySupplierAndDate(
    int supplierId,
    DateTime start,
    DateTime end,
  ) async {
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
    final newAmountDue = (sale.amountDue - paymentAmount).clamp(
      0.0,
      sale.amountDue,
    );

    await dbClient.update(
      'sales',
      {'amountDue': newAmountDue, 'isPaid': newAmountDue == 0.0 ? 1 : 0},
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

  // ───────────────EXPENSES ───────────────
  // Insertar gasto
  static Future<int> insertExpense(Expense expense) async {
    final dbClient = await db;
    return await dbClient.insert('expenses', expense.toMap());
  }

  static Future<List<Expense>> getExpenses() async {
    final dbClient = await db;
    final result = await dbClient.query('expenses');
    return result.map((e) => Expense.fromMap(e)).toList();
  }

  static Future<int> insertExpenseEntry(ExpenseEntry entry) async {
    final dbClient = await db;
    return await dbClient.insert('expense_entries', entry.toMap());
  }

  static Future<List<ExpenseEntry>> getEntriesByExpenseId(int expenseId) async {
    final dbClient = await db;
    final result = await dbClient.query(
      'expense_entries',
      where: 'expense_id = ?',
      whereArgs: [expenseId],
    );
    return result.map((e) => ExpenseEntry.fromMap(e)).toList();
  }

  static Future<List<Map<String, dynamic>>> getExpenseHistory(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final dbClient = await db;

    final result = await dbClient.rawQuery(
      '''
    SELECT e.name AS expense_name, ee.amount, ee.date
    FROM expense_entries ee
    JOIN expenses e ON ee.expense_id = e.id
    WHERE date(ee.date) BETWEEN ? AND ?
    ORDER BY ee.date DESC
  ''',
      [
        startDate.toIso8601String().split('T').first,
        endDate.toIso8601String().split('T').first,
      ],
    );

    return result
        .map(
          (row) => {
            'expense_name': row['expense_name'],
            'amount': row['amount'],
            'date': row['date'],
          },
        )
        .toList();
  }

  //reportes
  static Future<List<Map<String, dynamic>>> getPagosCreditoBetweenDates(
    DateTime start,
    DateTime end,
  ) async {
    final dbClient = await db;

    final result = await dbClient.query(
      'credit_payments',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [
        start.toIso8601String(),
        end.add(Duration(days: 1)).toIso8601String(),
      ],
    );

    return result;
  }

  static Future<List<Map<String, dynamic>>> getProductSalesReport(
    DateTime start,
    DateTime end,
  ) async {
    final dbClient = await db;

    final result = await dbClient.rawQuery(
      '''
    SELECT 
      p.name AS product_name,
      SUM(si.quantity) AS total_quantity,
      SUM(si.subtotal) AS total_sales,
      SUM(CASE WHEN si.discount > 0 THEN 1 ELSE 0 END) AS discount_applied
    FROM sale_items si
    JOIN sales s ON si.sale_id = s.id
    JOIN products p ON si.product_id = p.id
    WHERE date(s.date) BETWEEN ? AND ?
    GROUP BY si.product_id
    ORDER BY total_quantity DESC
  ''',
      [
        start.toIso8601String().split('T').first,
        end.toIso8601String().split('T').first,
      ],
    );

    return result;
  }

  static Future<Map<String, dynamic>> getResumenGeneral(
    DateTime start,
    DateTime end,
  ) async {
    final dbClient = await db;

    // Ventas filtradas por fecha
    final sales = await dbClient.query(
      'sales',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [
        start.toIso8601String(),
        end.add(const Duration(days: 1)).toIso8601String(),
      ],
    );

    int totalFacturas = sales.length;
    double totalVentas = 0;
    double pagosCredito = 0;
    double descuentos = 0;
    double ganancia = 0;
    int productosVendidos = 0;

    for (var sale in sales) {
      totalVentas += sale['total'] as double;

      final saleId = sale['id'] as int;
      final items = await dbClient.query(
        'sale_items',
        where: 'sale_id = ?',
        whereArgs: [saleId],
      );

      for (var item in items) {
        final quantity = item['quantity'] as int;
        final subtotal = item['subtotal'] as double;
        final discount = item['discount'] as double;
        final productId = item['product_id'] as int;

        productosVendidos += quantity;
        descuentos += discount * quantity;

        final product = await dbClient.query(
          'products',
          where: 'id = ?',
          whereArgs: [productId],
        );
        if (product.isNotEmpty) {
          final cost = product.first['cost'] as double;
          ganancia += ((subtotal / quantity) - cost) * quantity;
        }
      }

      if ((sale['isCredit'] as int) == 1) {
        pagosCredito +=
            (sale['total'] as double) - (sale['amountDue'] as double);
      }
    }

    // Entradas de inventario
    final inventory = await dbClient.query(
      'inventory_entries',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [
        start.toIso8601String(),
        end.add(const Duration(days: 1)).toIso8601String(),
      ],
    );

    double totalInventario = inventory.fold(
      0.0,
      (sum, e) => sum + ((e['cost'] as double) * (e['quantity'] as int)),
    );

    // Gastos
    final gastos = await dbClient.rawQuery(
      '''
    SELECT SUM(ee.amount) as totalGastos
    FROM expense_entries ee
    WHERE date(ee.date) BETWEEN ? AND ?
  ''',
      [
        start.toIso8601String().split('T').first,
        end.toIso8601String().split('T').first,
      ],
    );

    double totalGastos =
        gastos.first['totalGastos'] != null
            ? (gastos.first['totalGastos'] as num).toDouble()
            : 0.0;

    return {
      'facturas': totalFacturas,
      'ventas': totalVentas,
      'pagos_credito': pagosCredito,
      'descuentos': descuentos,
      'ganancia': ganancia,
      'productos': productosVendidos,
      'inventario': totalInventario,
      'gastos': totalGastos,
    };
  }

  static Future<List<Map<String, dynamic>>> getFacturasPorCliente(
    String phone,
    DateTime start,
    DateTime end,
  ) async {
    final dbClient = await db;

    final result = await dbClient.query(
      'sales',
      where: 'clientPhone = ? AND date BETWEEN ? AND ?',
      whereArgs: [
        phone,
        start.toIso8601String(),
        end.add(const Duration(days: 1)).toIso8601String(),
      ],
    );

    return result;
  }

  static Future<List<Map<String, dynamic>>> getRentableProductReport(
    DateTime start,
    DateTime end,
  ) async {
    final dbClient = await db;

    final result = await dbClient.rawQuery(
      '''
    SELECT 
      p.name AS product_name,
      COUNT(si.id) AS times_sold,
      SUM(si.subtotal) AS total_income,
      SUM(si.discount * si.quantity) AS total_discount
    FROM sale_items si
    JOIN sales s ON si.sale_id = s.id
    JOIN products p ON si.product_id = p.id
    WHERE p.is_rentable = 1 AND date(s.date) BETWEEN ? AND ?
    GROUP BY si.product_id
    ORDER BY total_income DESC
  ''',
      [
        start.toIso8601String().split('T').first,
        end.toIso8601String().split('T').first,
      ],
    );

    return result;
  }

  // Corregir el método savePaymentHistory
static Future<int> savePaymentHistory(
  String clientPhone,
  double amount,
  String receiptNumber,
  Map<int, double> affectedSales,
) async {
  final dbClient = await db;

  // Convertir el mapa de ventas afectadas a formato JSON para almacenamiento
  final affectedSalesJson = jsonEncode(
    affectedSales.map((key, value) => MapEntry(key.toString(), value)),
  );

  return await dbClient.insert('payment_history', {
    'client_phone': clientPhone,
    'amount': amount,
    'payment_date': DateTime.now().toIso8601String(),
    'receipt_number': receiptNumber,
    'affected_sales': affectedSalesJson,
    'created_at': DateTime.now().toIso8601String(),
  });
}

// Corregir el método getPaymentHistoryByClient
static Future<List<Map<String, dynamic>>> getPaymentHistoryByClient(
  String phone,
) async {
  final dbClient = await db;

  final result = await dbClient.query(
    'payment_history',
    where: 'client_phone = ?',
    whereArgs: [phone],
    orderBy: 'payment_date DESC',
  );

  return result;
}

// Corregir el método getPaymentById
static Future<Map<String, dynamic>?> getPaymentById(int id) async {
  final dbClient = await db;

  final result = await dbClient.query(
    'payment_history',
    where: 'id = ?',
    whereArgs: [id],
    limit: 1,
  );

  if (result.isEmpty) return null;
  return result.first;
}

// Corregir el método getPaymentHistoryByDateRange
static Future<List<Map<String, dynamic>>> getPaymentHistoryByDateRange(
  String phone,
  DateTime startDate,
  DateTime endDate,
) async {
  final dbClient = await db;

  final start = startDate.toIso8601String();
  final end = endDate.add(Duration(days: 1)).toIso8601String();

  final result = await dbClient.query(
    'payment_history',
    where: 'client_phone = ? AND payment_date BETWEEN ? AND ?',
    whereArgs: [phone, start, end],
    orderBy: 'payment_date DESC',
  );

  return result;
}
}
