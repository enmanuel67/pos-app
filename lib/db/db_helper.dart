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
import '../helpers/error_logger.dart';
import '../helpers/supabase_sync_helper.dart';
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
      version: 2, // ✅ subimos versión para poder agregar columnas nuevas
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
          createdAt TEXT,
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
        );
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
        );
      ''');

        await db.execute('''
        CREATE TABLE sales (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT,
          total REAL,
          amountDue REAL DEFAULT 0,
          clientPhone TEXT,
          isCredit INTEGER,
          isPaid INTEGER DEFAULT 0,

          -- ✅ NUEVO (para "eliminar" factura sin perder historial)
          isVoided INTEGER DEFAULT 0,
          voidedAt TEXT
        );
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
        );
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
        );
      ''');

        await db.execute('''
        CREATE TABLE expenses (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT
        );
      ''');

        await db.execute('''
        CREATE TABLE expense_entries (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          expense_id INTEGER,
          amount REAL,
          date TEXT,
          FOREIGN KEY (expense_id) REFERENCES expenses(id)
        );
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
        );
      ''');
      },

      // ✅ IMPORTANTE: si el usuario ya tiene DB creada, esto le agrega columnas sin borrar nada
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // ✅ PRODUCTS
          try {
            await db.execute(
              "ALTER TABLE products ADD COLUMN is_rentable INTEGER DEFAULT 0",
            );
          } catch (_) {}
          try {
            await db.execute("ALTER TABLE products ADD COLUMN createdAt TEXT");
          } catch (_) {}

          // ✅ SALES (void/anulada)
          try {
            await db.execute(
              "ALTER TABLE sales ADD COLUMN isVoided INTEGER DEFAULT 0",
            );
          } catch (_) {}
          try {
            await db.execute("ALTER TABLE sales ADD COLUMN voidedAt TEXT");
          } catch (_) {}
        }
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
    final id = await _nextSafeLocalId('suppliers');
    final supplierMap = supplier.toMap();
    supplierMap['id'] = id;
    await dbClient.insert('suppliers', supplierMap);
    await SupabaseSyncHelper.syncSupplier(
      Supplier(
        id: id,
        name: supplier.name,
        phone: supplier.phone,
        description: supplier.description,
        address: supplier.address,
        email: supplier.email,
      ),
    );
    return id;
  }

  static Future<List<Supplier>> getSuppliers() async {
    final dbClient = await db;
    try {
      final cloudSuppliers = await SupabaseSyncHelper.getSuppliers();
      if (cloudSuppliers.isNotEmpty) return cloudSuppliers;
    } catch (error, stackTrace) {
      await ErrorLogger.log(
        source: 'DBHelper.getSuppliers',
        error: error,
        stackTrace: stackTrace,
        details: 'No se pudo leer proveedores desde Supabase. Se usara SQLite.',
      );
    }

    final result = await dbClient.query('suppliers');
    return result.map((e) => Supplier.fromMap(e)).toList();
  }

  static Future<int> updateSupplier(Supplier supplier) async {
    final dbClient = await db;
    final updated = await dbClient.update(
      'suppliers',
      supplier.toMap(),
      where: 'id = ?',
      whereArgs: [supplier.id],
    );
    await SupabaseSyncHelper.syncSupplier(supplier);
    return updated;
  }

  static Future<void> deleteSupplier(int id) async {
    final dbClient = await db;
    await dbClient.delete('suppliers', where: 'id = ?', whereArgs: [id]);
    await SupabaseSyncHelper.markDeleted('suppliers', id);
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
    try {
      final cloudProducts = await SupabaseSyncHelper.getProducts();
      if (cloudProducts.isNotEmpty) {
        for (final product in cloudProducts) {
          if (product.id == null) continue;
          await dbClient.insert(
            'products',
            product.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        return cloudProducts;
      }
    } catch (error, stackTrace) {
      await ErrorLogger.log(
        source: 'DBHelper.getProducts',
        error: error,
        stackTrace: stackTrace,
        details: 'No se pudo leer productos desde Supabase. Se usara SQLite.',
      );
    }

    final maps = await dbClient.query(
      'products',
      orderBy: 'datetime(createdAt) DESC', // ✅ más nuevo primero
    );
    return maps.map((e) => Product.fromMap(e)).toList();
  }

  static Future<int> insertProduct(Product product) async {
    final dbClient = await db;
    final id = await _nextSafeLocalId('products');
    final productMap = product.toMap();
    final createdAt = DateTime.now().toIso8601String();
    productMap['id'] = id;
    productMap['createdAt'] = createdAt; // ← agregado
    await dbClient.insert('products', productMap);
    await SupabaseSyncHelper.syncProduct(
      product.copyWith(id: id, createdAt: createdAt),
    );
    return id;
  }

  static Future<int> updateProduct(Product product) async {
    final dbClient = await db;
    final updated = await dbClient.update(
      'products',
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
    await SupabaseSyncHelper.syncProduct(product);
    return updated;
  }

  static Future<void> deleteProduct(int id) async {
    final dbClient = await db;
    await dbClient.delete('products', where: 'id = ?', whereArgs: [id]);
    await SupabaseSyncHelper.markDeleted('products', id);
  }

  Future<void> reduceProductStock(int productId, int quantity) async {
    final dbClient = await db;

    final result = await dbClient.query(
      'products',
      where: 'id = ?',
      whereArgs: [productId],
      limit: 1,
    );

    if (result.isEmpty) return;

    final row = result.first;

    // ✅ Si es rentable, NO bajar inventario (producto “infinito”)
    final isRentable = (row['is_rentable'] as int?) == 1;
    if (isRentable) return;

    final currentQty = (row['quantity'] as num?)?.toInt() ?? 0;
    if (quantity <= 0) return;
    if (currentQty < quantity) {
      throw Exception('Stock insuficiente para producto ID $productId');
    }
    final newQty = currentQty - quantity;

    await dbClient.update(
      'products',
      {'quantity': newQty},
      where: 'id = ?',
      whereArgs: [productId],
    );

    final updatedProduct = await getProductById(productId);
    if (updatedProduct != null) {
      await SupabaseSyncHelper.syncProduct(updatedProduct);
    }

    // ✅ Verificación de stock bajo (solo productos NO rentables)
    if (newQty <= 5) {
      print('⚠ Bajo inventario para producto ID $productId ($newQty unidades)');

      final lowStock = await dbClient.query(
        'products',
        where: 'quantity <= ? AND (is_rentable IS NULL OR is_rentable = 0)',
        whereArgs: [5],
      );
      InventoryNotifier.lowStockCount.value = lowStock.length;
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
    try {
      return await SupabaseSyncHelper.getProductSalesByBusiness(
        businessType,
        start,
        end,
      );
    } catch (error, stackTrace) {
      await ErrorLogger.log(
        source: 'DBHelper.getProductSalesByBusiness',
        error: error,
        stackTrace: stackTrace,
        details: 'No se pudo leer reporte desde Supabase. Se usara SQLite.',
      );
    }

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
     WHERE p.business_type = ?
      AND date(s.date) BETWEEN ? AND ?
      AND (s.isVoided IS NULL OR s.isVoided = 0)   -- ✅ EXCLUIR ANULADAS
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
      final inventoryEntryId = await _nextSafeLocalId('inventory_entries');
      final inventoryEntry = {
        'id': inventoryEntryId,
        'product_id': productId,
        'supplier_id': current['supplierId'],
        'quantity': addedQuantity,
        'cost': unitCost,
        'date': DateTime.now().toIso8601String(),
      };
      await dbClient.insert('inventory_entries', inventoryEntry);
      await SupabaseSyncHelper.syncInventoryEntry(inventoryEntry);

      final updatedProduct = await getProductById(productId);
      if (updatedProduct != null) {
        await SupabaseSyncHelper.syncProduct(updatedProduct);
      }
    }
  }

  static Future<List<Map<String, dynamic>>>
  getInventoryEntriesBySupplierAndDate(
    int supplierId,
    DateTime start,
    DateTime end,
  ) async {
    final dbClient = await db;
    try {
      return await SupabaseSyncHelper.getInventoryEntriesBySupplierAndDate(
        supplierId,
        start,
        end,
      );
    } catch (error, stackTrace) {
      await ErrorLogger.log(
        source: 'DBHelper.getInventoryEntriesBySupplierAndDate',
        error: error,
        stackTrace: stackTrace,
        details: 'No se pudo leer inventario desde Supabase. Se usara SQLite.',
      );
    }

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

  static Future<DateTime?> getLastInventoryEntryDate(int productId) async {
    final dbClient = await db;

    final result = await dbClient.query(
      'inventory_entries',
      columns: ['date'],
      where: 'product_id = ?',
      whereArgs: [productId],
      orderBy: 'date DESC',
      limit: 1,
    );

    if (result.isEmpty) return null;

    final raw = result.first['date'] as String?;
    if (raw == null || raw.isEmpty) return null;

    return DateTime.tryParse(raw);
  }

  // ─────────────── CLIENTS ───────────────
  static Future<int> insertClient(Client client) async {
    final dbClient = await db;
    final id = await _nextSafeLocalId('clients');
    final clientMap = client.toMap();
    clientMap['id'] = id;
    await dbClient.insert('clients', clientMap);
    await SupabaseSyncHelper.syncClient(
      Client(
        id: id,
        name: client.name,
        lastName: client.lastName,
        phone: client.phone,
        address: client.address,
        email: client.email,
        hasCredit: client.hasCredit,
        creditLimit: client.creditLimit,
        credit: client.credit,
        creditAvailable: client.creditAvailable,
      ),
    );
    return id;
  }

  static Future<List<Client>> getClients() async {
    final dbClient = await db;
    try {
      final cloudClients = await SupabaseSyncHelper.getClients();
      if (cloudClients.isNotEmpty) {
        for (final client in cloudClients) {
          if (client.id == null) continue;
          await dbClient.insert(
            'clients',
            client.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        return cloudClients;
      }
    } catch (error, stackTrace) {
      await ErrorLogger.log(
        source: 'DBHelper.getClients',
        error: error,
        stackTrace: stackTrace,
        details: 'No se pudo leer clientes desde Supabase. Se usara SQLite.',
      );
    }

    final result = await dbClient.query('clients');
    return result.map((e) => Client.fromMap(e)).toList();
  }

  static Future<int> updateClient(Client client) async {
    final dbClient = await db;
    final updated = await dbClient.update(
      'clients',
      client.toMap(),
      where: 'id = ?',
      whereArgs: [client.id],
    );
    await SupabaseSyncHelper.syncClient(client);
    return updated;
  }

  static Future<int> deleteClient(int id) async {
    final dbClient = await db;
    final deleted = await dbClient.delete(
      'clients',
      where: 'id = ?',
      whereArgs: [id],
    );
    await SupabaseSyncHelper.markDeleted('clients', id);
    return deleted;
  }

  static Future<Client?> getClientByPhone(String phone) async {
    final dbClient = await db;
    final result = await dbClient.query(
      'clients',
      where: 'phone = ?',
      whereArgs: [phone],
      limit: 1,
    );
    if (result.isNotEmpty) {
      return Client.fromMap(result.first);
    }

    try {
      final cloudClients = await getClients();
      for (final client in cloudClients) {
        if (client.phone.trim() == phone.trim()) {
          return client;
        }
      }
    } catch (error, stackTrace) {
      await ErrorLogger.log(
        source: 'DBHelper.getClientByPhone',
        error: error,
        stackTrace: stackTrace,
        details: 'No se pudo resolver cliente por telefono desde Supabase.',
      );
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
    final updatedClient = await getClientByPhone(phone);
    if (updatedClient != null) {
      await SupabaseSyncHelper.syncClient(updatedClient);
    }
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
    final updatedClient = await getClientByPhone(phone);
    if (updatedClient != null) {
      await SupabaseSyncHelper.syncClient(updatedClient);
    }
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
    final updatedClient = await getClientByPhone(phone);
    if (updatedClient != null) {
      await SupabaseSyncHelper.syncClient(updatedClient);
    }
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

    final updatedSaleRows = await dbClient.query(
      'sales',
      where: 'id = ?',
      whereArgs: [saleId],
      limit: 1,
    );
    if (updatedSaleRows.isNotEmpty) {
      await SupabaseSyncHelper.syncSale(updatedSaleRows.first);
    }
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
    final id = await _nextSafeLocalId('sales');
    final saleMap = sale.toMap();
    saleMap['id'] = id;
    await dbClient.insert('sales', saleMap);
    await SupabaseSyncHelper.syncSale(saleMap);
    return id;
  }

  static Future<void> insertSaleItems(List<SaleItem> items) async {
    final dbClient = await db;
    for (var item in items) {
      final id = await _nextSafeLocalId('sale_items');
      final itemMap = item.toMap();
      itemMap['id'] = id;
      await dbClient.insert('sale_items', itemMap);
      await SupabaseSyncHelper.syncSaleItem(itemMap);
    }
  }

  // ─────────────── History SALES (Auditoría) ───────────────
  static Future<List<Sale>> getAllSales() async {
    final dbClient = await db;
    try {
      return await SupabaseSyncHelper.getAllSales();
    } catch (error, stackTrace) {
      await ErrorLogger.log(
        source: 'DBHelper.getAllSales',
        error: error,
        stackTrace: stackTrace,
        details: 'No se pudo leer ventas desde Supabase. Se usara SQLite.',
      );
    }

    final result = await dbClient.query('sales', orderBy: 'date DESC');

    return result.map((e) => Sale.fromMap(e)).toList();
  }

  // Obtener los ítems (productos vendidos) de una venta específica
  static Future<List<SaleItem>> getSaleItems(int saleId) async {
    final dbClient = await db;
    try {
      return await SupabaseSyncHelper.getSaleItems(saleId);
    } catch (error, stackTrace) {
      await ErrorLogger.log(
        source: 'DBHelper.getSaleItems',
        error: error,
        stackTrace: stackTrace,
        details: 'No se pudo leer items desde Supabase. Se usara SQLite.',
      );
    }

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
    try {
      final cloudSale = await SupabaseSyncHelper.getSaleById(id);
      if (cloudSale != null) return cloudSale;
    } catch (error, stackTrace) {
      await ErrorLogger.log(
        source: 'DBHelper.getSaleById',
        error: error,
        stackTrace: stackTrace,
        details: 'No se pudo leer venta desde Supabase. Se usara SQLite.',
      );
    }

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
    final id = await _nextSafeLocalId('expenses');
    final expenseMap = expense.toMap();
    expenseMap['id'] = id;
    await dbClient.insert(
      'expenses',
      expenseMap,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await SupabaseSyncHelper.syncExpense(Expense(id: id, name: expense.name));
    return id;
  }

  static Future<List<Expense>> getExpenses() async {
    final dbClient = await db;
    try {
      final cloudExpenses = await SupabaseSyncHelper.getExpenses();
      for (final expense in cloudExpenses) {
        if (expense.id == null) continue;
        await dbClient.insert(
          'expenses',
          expense.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      return cloudExpenses;
    } catch (error, stackTrace) {
      await ErrorLogger.log(
        source: 'DBHelper.getExpenses',
        error: error,
        stackTrace: stackTrace,
        details: 'No se pudo leer gastos desde Supabase. Se usara SQLite.',
      );
    }

    final result = await dbClient.query('expenses');
    return result.map((e) => Expense.fromMap(e)).toList();
  }

  static Future<int> insertExpenseEntry(ExpenseEntry entry) async {
    final dbClient = await db;
    await _ensureLocalExpense(entry.expenseId);

    final id = await _nextSafeLocalId('expense_entries');
    final entryMap = entry.toMap();
    entryMap['id'] = id;
    await dbClient.insert(
      'expense_entries',
      entryMap,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    final expenseRows = await dbClient.query(
      'expenses',
      where: 'id = ?',
      whereArgs: [entry.expenseId],
      limit: 1,
    );
    if (expenseRows.isNotEmpty) {
      await SupabaseSyncHelper.syncExpense(Expense.fromMap(expenseRows.first));
    }
    await SupabaseSyncHelper.syncExpenseEntry(
      ExpenseEntry(
        id: id,
        expenseId: entry.expenseId,
        amount: entry.amount,
        date: entry.date,
      ),
    );
    return id;
  }

  static Future<void> _ensureLocalExpense(int expenseId) async {
    final dbClient = await db;
    final localRows = await dbClient.query(
      'expenses',
      where: 'id = ?',
      whereArgs: [expenseId],
      limit: 1,
    );
    if (localRows.isNotEmpty) return;

    try {
      final cloudExpense = await SupabaseSyncHelper.getExpenseByLocalId(
        expenseId,
      );
      if (cloudExpense != null && cloudExpense.id != null) {
        await dbClient.insert(
          'expenses',
          cloudExpense.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        return;
      }
    } catch (error, stackTrace) {
      await ErrorLogger.log(
        source: 'DBHelper._ensureLocalExpense',
        error: error,
        stackTrace: stackTrace,
        details:
            'No se pudo confirmar el gasto en Supabase antes de registrar la entrada.',
      );
    }

    await dbClient.insert('expenses', {
      'id': expenseId,
      'name': 'Gasto #$expenseId',
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
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
    try {
      await _syncLocalExpenseEntries(startDate, endDate);
      final cloudHistory = await SupabaseSyncHelper.getExpenseHistory(
        startDate,
        endDate,
      );
      if (cloudHistory.isNotEmpty) return cloudHistory;
    } catch (error, stackTrace) {
      await ErrorLogger.log(
        source: 'DBHelper.getExpenseHistory',
        error: error,
        stackTrace: stackTrace,
        details:
            'No se pudo leer historial de gastos desde Supabase. Se usara SQLite.',
      );
    }

    return await _getLocalExpenseHistory(startDate, endDate);
  }

  static Future<List<Map<String, dynamic>>> _getLocalExpenseHistory(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final dbClient = await db;
    final result = await dbClient.rawQuery(
      '''
    SELECT ee.id, ee.expense_id, e.name AS expense_name, ee.amount, ee.date
    FROM expense_entries ee
    LEFT JOIN expenses e ON ee.expense_id = e.id
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
            'id': row['id'],
            'expense_id': row['expense_id'],
            'expense_name':
                row['expense_name'] ?? 'Gasto #${row['expense_id']}',
            'amount': row['amount'],
            'date': row['date'],
          },
        )
        .toList();
  }

  static Future<void> _syncLocalExpenseEntries(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final dbClient = await db;
    final rows = await dbClient.query(
      'expense_entries',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [
        startDate.toIso8601String(),
        endDate.add(const Duration(days: 1)).toIso8601String(),
      ],
    );

    for (final row in rows) {
      final expenseId = (row['expense_id'] as num?)?.toInt();
      if (expenseId == null || expenseId <= 0) continue;

      final expenseRows = await dbClient.query(
        'expenses',
        where: 'id = ?',
        whereArgs: [expenseId],
        limit: 1,
      );
      if (expenseRows.isNotEmpty) {
        await SupabaseSyncHelper.syncExpense(
          Expense.fromMap(expenseRows.first),
        );
      }

      await SupabaseSyncHelper.syncExpenseEntry(ExpenseEntry.fromMap(row));
    }
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
    try {
      return await SupabaseSyncHelper.getResumenGeneral(start, end);
    } catch (error, stackTrace) {
      await ErrorLogger.log(
        source: 'DBHelper.getResumenGeneral',
        error: error,
        stackTrace: stackTrace,
        details: 'No se pudo leer resumen desde Supabase. Se usara SQLite.',
      );
    }

    // ✅ Ventas filtradas por fecha (EXCLUYE anuladas)
    final sales = await dbClient.query(
      'sales',
      where: 'date BETWEEN ? AND ? AND (isVoided IS NULL OR isVoided = 0)',
      whereArgs: [
        start.toIso8601String(),
        end.add(const Duration(days: 1)).toIso8601String(),
      ],
    );

    int totalFacturas = sales.length;
    double totalVentas = 0.0;
    double pagosCredito = 0.0;
    double descuentos = 0.0;
    double ganancia = 0.0;
    int productosVendidos = 0;

    for (var sale in sales) {
      totalVentas += (sale['total'] as num?)?.toDouble() ?? 0.0;

      final saleId = sale['id'] as int;
      final items = await dbClient.query(
        'sale_items',
        where: 'sale_id = ?',
        whereArgs: [saleId],
      );

      for (var item in items) {
        final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
        if (quantity <= 0) continue;

        final subtotal = (item['subtotal'] as num?)?.toDouble() ?? 0.0;
        final discount = (item['discount'] as num?)?.toDouble() ?? 0.0;
        final productId = item['product_id'] as int;

        productosVendidos += quantity;
        descuentos += discount * quantity;

        final product = await dbClient.query(
          'products',
          columns: ['cost'],
          where: 'id = ?',
          whereArgs: [productId],
          limit: 1,
        );

        if (product.isNotEmpty) {
          final cost = (product.first['cost'] as num?)?.toDouble() ?? 0.0;
          ganancia += ((subtotal / quantity) - cost) * quantity;
        }
      }

      if ((sale['isCredit'] as int? ?? 0) == 1) {
        final total = (sale['total'] as num?)?.toDouble() ?? 0.0;
        final amountDue = (sale['amountDue'] as num?)?.toDouble() ?? 0.0;
        pagosCredito += (total - amountDue);
      }
    }

    // Entradas de inventario (esto NO depende de sales, así que se queda igual)
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
      (sum, e) =>
          sum +
          (((e['cost'] as num?)?.toDouble() ?? 0.0) *
              ((e['quantity'] as num?)?.toInt() ?? 0)),
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
    try {
      return await SupabaseSyncHelper.getFacturasPorCliente(phone, start, end);
    } catch (error, stackTrace) {
      await ErrorLogger.log(
        source: 'DBHelper.getFacturasPorCliente',
        error: error,
        stackTrace: stackTrace,
        details:
            'No se pudo leer facturas por cliente desde Supabase. Se usara SQLite.',
      );
    }

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
    try {
      return await SupabaseSyncHelper.getRentableProductReport(start, end);
    } catch (error, stackTrace) {
      await ErrorLogger.log(
        source: 'DBHelper.getRentableProductReport',
        error: error,
        stackTrace: stackTrace,
        details:
            'No se pudo leer reporte de rentables desde Supabase. Se usara SQLite.',
      );
    }

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
    WHERE p.is_rentable = 1 
      AND date(s.date) BETWEEN ? AND ?
      AND (s.isVoided IS NULL OR s.isVoided = 0) 
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

    final id = await _nextSafeLocalId('payment_history');
    final paymentMap = {
      'id': id,
      'client_phone': clientPhone,
      'amount': amount,
      'payment_date': DateTime.now().toIso8601String(),
      'receipt_number': receiptNumber,
      'affected_sales': affectedSalesJson,
      'created_at': DateTime.now().toIso8601String(),
    };
    await dbClient.insert('payment_history', paymentMap);
    await SupabaseSyncHelper.syncPaymentHistory(paymentMap);
    return id;
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

  static Future<List<Map<String, dynamic>>> getPaymentHistoryBetweenDates(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final dbClient = await db;
    try {
      return await SupabaseSyncHelper.getPaymentHistoryBetweenDates(
        startDate,
        endDate,
      );
    } catch (error, stackTrace) {
      await ErrorLogger.log(
        source: 'DBHelper.getPaymentHistoryBetweenDates',
        error: error,
        stackTrace: stackTrace,
        details:
            'No se pudo leer pagos por fecha desde Supabase. Se usara SQLite.',
      );
    }

    final start = startDate.toIso8601String();
    final end = endDate.add(const Duration(days: 1)).toIso8601String();

    return await dbClient.query(
      'payment_history',
      where: 'payment_date BETWEEN ? AND ?',
      whereArgs: [start, end],
      orderBy: 'payment_date DESC',
    );
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
    try {
      return await SupabaseSyncHelper.getPaymentHistoryByDateRange(
        phone,
        startDate,
        endDate,
      );
    } catch (error, stackTrace) {
      await ErrorLogger.log(
        source: 'DBHelper.getPaymentHistoryByDateRange',
        error: error,
        stackTrace: stackTrace,
        details: 'No se pudo leer pagos desde Supabase. Se usara SQLite.',
      );
    }

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

  // Anular venta + devolver inventario + arreglar crédito

  static Future<void> voidSaleAndRestock(int saleId) async {
    final dbClient = await db;

    await dbClient.transaction((txn) async {
      // 1) Leer la venta
      final saleRes = await txn.query(
        'sales',
        where: 'id = ?',
        whereArgs: [saleId],
        limit: 1,
      );
      if (saleRes.isEmpty) throw Exception("Venta no existe");

      final sale = saleRes.first;

      // si ya está anulada, no hacer nada
      final isVoided = (sale['isVoided'] ?? 0) as int;
      if (isVoided == 1) return;

      final isCredit = (sale['isCredit'] as int) == 1;
      final total = (sale['total'] as num).toDouble();
      final amountDue = (sale['amountDue'] as num).toDouble();
      final clientPhone = sale['clientPhone'] as String?;

      // 2) Obtener items de la venta
      final items = await txn.query(
        'sale_items',
        where: 'sale_id = ?',
        whereArgs: [saleId],
      );

      // 3) Devolver inventario
      for (final it in items) {
        final productId = it['product_id'] as int;
        final qty = (it['quantity'] as num).toInt();

        await txn.rawUpdate(
          'UPDATE products SET quantity = quantity + ? WHERE id = ?',
          [qty, productId],
        );
      }

      // 4) Si era crédito, revertir el crédito del cliente
      // pagosRecibidos = total - amountDue
      if (isCredit && clientPhone != null && clientPhone.isNotEmpty) {
        final clientRes = await txn.query(
          'clients',
          where: 'phone = ?',
          whereArgs: [clientPhone],
          limit: 1,
        );

        if (clientRes.isNotEmpty) {
          final client = clientRes.first;

          final credit = (client['credit'] as num?)?.toDouble() ?? 0.0;
          final creditLimit =
              (client['creditLimit'] as num?)?.toDouble() ?? 0.0;
          final creditAvailable =
              (client['creditAvailable'] as num?)?.toDouble() ?? 0.0;

          // En tu lógica: credit = deuda, creditAvailable = disponible
          // Esta venta aportó:
          // - deudaGenerada = amountDue (lo que aún debía)
          // - pagosRecibidos = total - amountDue (ya pagado)
          final deudaGenerada = amountDue;
          final pagosRecibidos = total - amountDue;

          final newCredit = (credit - deudaGenerada).clamp(0.0, creditLimit);
          final newAvailable = (creditAvailable + deudaGenerada).clamp(
            0.0,
            creditLimit,
          );

          await txn.update(
            'clients',
            {'credit': newCredit, 'creditAvailable': newAvailable},
            where: 'phone = ?',
            whereArgs: [clientPhone],
          );

          // Nota importante:
          // Si tú guardas recibos en payment_history relacionados a esta sale,
          // idealmente deberías marcarlos como anulados también.
          // (Más abajo te digo cómo).
        }
      }

      // 5) Marcar venta como anulada (esto la saca de reportes)
      await txn.update(
        'sales',
        {
          'isVoided': 1,
          'voidedAt': DateTime.now().toIso8601String(),
          'total': 0.0,
          'amountDue': 0.0,
          'isPaid': 1,
        },
        where: 'id = ?',
        whereArgs: [saleId],
      );
    });

    final updatedSaleRows = await dbClient.query(
      'sales',
      where: 'id = ?',
      whereArgs: [saleId],
      limit: 1,
    );
    if (updatedSaleRows.isNotEmpty) {
      await SupabaseSyncHelper.syncSale(updatedSaleRows.first);
      final clientPhone = updatedSaleRows.first['clientPhone']?.toString();
      if (clientPhone != null && clientPhone.isNotEmpty) {
        final client = await getClientByPhone(clientPhone);
        if (client != null) await SupabaseSyncHelper.syncClient(client);
      }
    }

    final items = await dbClient.query(
      'sale_items',
      where: 'sale_id = ?',
      whereArgs: [saleId],
    );
    for (final item in items) {
      final productId = item['product_id'] as int?;
      if (productId == null) continue;
      final product = await getProductById(productId);
      if (product != null) await SupabaseSyncHelper.syncProduct(product);
    }
  }

  static Future<void> _ensureInventoryDraftTable() async {
    final dbClient = await db;
    await dbClient.execute('''
    CREATE TABLE IF NOT EXISTS inventory_drafts(
      draft_key TEXT PRIMARY KEY,
      payload TEXT,
      updated_at TEXT
    );
  ''');
  }

  static Future<void> saveInventoryDraft(
    String draftKey,
    String payload,
  ) async {
    await _ensureInventoryDraftTable();
    final dbClient = await db;
    final updatedAt = DateTime.now().toIso8601String();
    await dbClient.insert('inventory_drafts', {
      'draft_key': draftKey,
      'payload': payload,
      'updated_at': updatedAt,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await SupabaseSyncHelper.syncInventoryDraft(
      draftKey: draftKey,
      payload: payload,
      updatedAt: updatedAt,
    );
  }

  static Future<String?> getInventoryDraft(String draftKey) async {
    await _ensureInventoryDraftTable();
    final dbClient = await db;
    try {
      final cloudPayload = await SupabaseSyncHelper.getInventoryDraft(draftKey);
      if (cloudPayload != null && cloudPayload.trim().isNotEmpty) {
        await dbClient.insert('inventory_drafts', {
          'draft_key': draftKey,
          'payload': cloudPayload,
          'updated_at': DateTime.now().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        return cloudPayload;
      }
    } catch (error, stackTrace) {
      await ErrorLogger.log(
        source: 'DBHelper.getInventoryDraft',
        error: error,
        stackTrace: stackTrace,
        details:
            'No se pudo leer borrador de inventario desde Supabase. Se usara SQLite.',
      );
    }

    final result = await dbClient.query(
      'inventory_drafts',
      where: 'draft_key = ?',
      whereArgs: [draftKey],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return result.first['payload'] as String?;
  }

  static Future<void> deleteInventoryDraft(String draftKey) async {
    await _ensureInventoryDraftTable();
    final dbClient = await db;
    await dbClient.delete(
      'inventory_drafts',
      where: 'draft_key = ?',
      whereArgs: [draftKey],
    );
    await SupabaseSyncHelper.deleteInventoryDraft(draftKey);
  }

  static Future<int> _nextSafeLocalId(String table) async {
    final dbClient = await db;
    final localMaxResult = await dbClient.rawQuery(
      'SELECT MAX(id) AS max_id FROM $table',
    );
    final localMax = (localMaxResult.first['max_id'] as num?)?.toInt() ?? 0;
    final cloudMax = await SupabaseSyncHelper.getMaxLocalId(table) ?? 0;
    return (localMax > cloudMax ? localMax : cloudMax) + 1;
  }
}
