import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/product.dart';
import '../models/supplier.dart';
import '../models/client.dart';

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
        // ✅ Tabla de productos
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

        // ✅ Tabla de proveedores
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
  creditLimit REAL
)
''');

      },
    );
  }

static Future<void> deleteDatabaseFile() async {
  final path = join(await getDatabasesPath(), 'pos.db');
  await deleteDatabase(path);
}

 
  // Insertar proveedor
  static Future<int> insertSupplier(Supplier supplier) async {
    final dbClient = await db;
    return await dbClient.insert('suppliers', supplier.toMap());
  }

  // Obtener todos los proveedores
  static Future<List<Supplier>> getSuppliers() async {
    final dbClient = await db;
    final result = await dbClient.query('suppliers');
    return result.map((e) => Supplier.fromMap(e)).toList();
  }

  // Actualizar proveedor
static Future<int> updateSupplier(Supplier supplier) async {
  final dbClient = await db;
  return await dbClient.update(
    'suppliers',
    supplier.toMap(),
    where: 'id = ?',
    whereArgs: [supplier.id],
  );
}

// Eliminar proveedor
static Future<void> deleteSupplier(int id) async {
  final dbClient = await db;
  await dbClient.delete('suppliers', where: 'id = ?', whereArgs: [id]);
}

//obtener productos
  static Future<List<Product>> getProducts() async {
    final dbClient = await db;
    final maps = await dbClient.query('products');
    return maps.map((e) => Product.fromMap(e)).toList();
  }

  // Insertar producto
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

// Insertar cliente
static Future<int> insertClient(Client client) async {
  final dbClient = await db;
  return await dbClient.insert('clients', client.toMap());
}

// Obtener todos los clientes
static Future<List<Client>> getClients() async {
  final dbClient = await db;
  final result = await dbClient.query('clients');
  return result.map((e) => Client.fromMap(e)).toList();
}

// Actualizar cliente
static Future<int> updateClient(Client client) async {
  final dbClient = await db;
  return await dbClient.update(
    'clients',
    client.toMap(),
    where: 'id = ?',
    whereArgs: [client.id],
  );
}

// Eliminar cliente
static Future<int> deleteClient(int id) async {
  final dbClient = await db;
  return await dbClient.delete('clients', where: 'id = ?', whereArgs: [id]);
}

}
