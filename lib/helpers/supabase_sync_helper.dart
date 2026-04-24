import 'dart:convert';

import 'package:pos_app/models/client.dart';
import 'package:pos_app/models/expense.dart';
import 'package:pos_app/models/expense_entry.dart';
import 'package:pos_app/models/product.dart';
import 'package:pos_app/models/sale.dart';
import 'package:pos_app/models/sale_item.dart';
import 'package:pos_app/models/supplier.dart';

import 'error_logger.dart';
import 'supabase_helper.dart';

class SupabaseSyncHelper {
  static Future<int?> getMaxLocalId(String table) async {
    try {
      final rows = await SupabaseHelper.client
          .from(table)
          .select('local_id')
          .not('local_id', 'is', null)
          .order('local_id', ascending: false)
          .limit(1);

      if (rows.isEmpty) return null;
      return _toInt(rows.first['local_id']);
    } catch (_) {
      return null;
    }
  }

  static Future<List<Supplier>> getSuppliers() async {
    final rows = await SupabaseHelper.client
        .from('suppliers')
        .select()
        .filter('deleted_at', 'is', null)
        .order('name', ascending: true);

    return rows.map<Supplier>((row) {
      return Supplier(
        id: row['local_id'] as int?,
        name: (row['name'] ?? '').toString(),
        phone: (row['phone'] ?? '').toString(),
        description: (row['description'] ?? '').toString(),
        address: (row['address'] ?? '').toString(),
        email: (row['email'] ?? '').toString(),
      );
    }).toList();
  }

  static Future<List<Product>> getProducts() async {
    final rows = await SupabaseHelper.client
        .from('products')
        .select()
        .filter('deleted_at', 'is', null)
        .order('original_created_at', ascending: false);

    return rows.map<Product>((row) {
      return Product(
        id: row['local_id'] as int?,
        name: (row['name'] ?? '').toString(),
        barcode: (row['barcode'] ?? '').toString(),
        description: (row['description'] ?? '').toString(),
        price: _toDouble(row['price']),
        quantity: _toInt(row['quantity']),
        cost: _toDouble(row['cost']),
        supplierId: _toInt(row['local_supplier_id']),
        createdAt:
            (row['original_created_at'] ?? row['created_at'] ?? '').toString(),
        businessType: row['business_type']?.toString(),
        isRentable: row['is_rentable'] == true,
      );
    }).toList();
  }

  static Future<List<Client>> getClients() async {
    final rows = await SupabaseHelper.client
        .from('clients')
        .select()
        .filter('deleted_at', 'is', null)
        .order('name', ascending: true);

    return rows.map<Client>((row) {
      return Client(
        id: row['local_id'] as int?,
        name: (row['name'] ?? '').toString(),
        lastName: (row['last_name'] ?? '').toString(),
        phone: (row['phone'] ?? '').toString(),
        address: (row['address'] ?? '').toString(),
        email: (row['email'] ?? '').toString(),
        hasCredit: row['has_credit'] == true,
        creditLimit: _toDouble(row['credit_limit']),
        credit: _toDouble(row['credit']),
        creditAvailable: _toDouble(row['credit_available']),
      );
    }).toList();
  }

  static Future<List<Expense>> getExpenses() async {
    final rows = await SupabaseHelper.client
        .from('expenses')
        .select()
        .filter('deleted_at', 'is', null)
        .order('name', ascending: true);

    return rows.map<Expense>((row) {
      return Expense(
        id: row['local_id'] as int?,
        name: (row['name'] ?? '').toString(),
      );
    }).toList();
  }

  static Future<Expense?> getExpenseByLocalId(int localId) async {
    if (localId <= 0) return null;

    final rows = await SupabaseHelper.client
        .from('expenses')
        .select()
        .eq('local_id', localId)
        .filter('deleted_at', 'is', null)
        .limit(1);

    if (rows.isEmpty) return null;
    final row = rows.first;
    return Expense(
      id: row['local_id'] as int?,
      name: row['name']?.toString() ?? '',
    );
  }

  static Future<List<Sale>> getAllSales() async {
    final rows = await SupabaseHelper.client
        .from('sales')
        .select()
        .order('sale_date', ascending: false);

    return rows.map<Sale>((row) => Sale.fromMap(_saleToLocalMap(row))).toList();
  }

  static Future<Sale?> getSaleById(int saleId) async {
    final rows = await SupabaseHelper.client
        .from('sales')
        .select()
        .eq('local_id', saleId)
        .limit(1);

    if (rows.isEmpty) return null;
    return Sale.fromMap(_saleToLocalMap(rows.first));
  }

  static Future<List<SaleItem>> getSaleItems(int saleId) async {
    final rows = await SupabaseHelper.client
        .from('sale_items')
        .select()
        .eq('local_sale_id', saleId);

    return rows
        .map<SaleItem>((row) => SaleItem.fromMap(_saleItemToLocalMap(row)))
        .toList();
  }

  static Future<List<Map<String, dynamic>>> getFacturasPorCliente(
    String phone,
    DateTime start,
    DateTime end,
  ) async {
    final rows = await SupabaseHelper.client
        .from('sales')
        .select()
        .eq('client_phone', phone)
        .gte('sale_date', start.toIso8601String())
        .lt('sale_date', end.add(const Duration(days: 1)).toIso8601String())
        .order('sale_date', ascending: false);

    return rows.map<Map<String, dynamic>>(_saleToLocalMap).toList();
  }

  static Future<List<Map<String, dynamic>>>
  getInventoryEntriesBySupplierAndDate(
    int supplierId,
    DateTime start,
    DateTime end,
  ) async {
    final rows = await SupabaseHelper.client
        .from('inventory_entries')
        .select()
        .eq('local_supplier_id', supplierId)
        .gte('entry_date', start.toIso8601String())
        .lt('entry_date', end.add(const Duration(days: 1)).toIso8601String());

    return rows.map<Map<String, dynamic>>((row) {
      return {
        'id': row['local_id'],
        'product_id': row['local_product_id'],
        'supplier_id': row['local_supplier_id'],
        'quantity': row['quantity'],
        'cost': _toDouble(row['cost']),
        'date': row['entry_date']?.toString(),
      };
    }).toList();
  }

  static Future<List<Map<String, dynamic>>> getPaymentHistoryByDateRange(
    String phone,
    DateTime start,
    DateTime end,
  ) async {
    final rows = await SupabaseHelper.client
        .from('payment_history')
        .select()
        .eq('client_phone', phone)
        .gte('payment_date', start.toIso8601String())
        .lt('payment_date', end.add(const Duration(days: 1)).toIso8601String())
        .order('payment_date', ascending: false);

    return rows.map<Map<String, dynamic>>((row) {
      return {
        'id': row['local_id'],
        'client_phone': row['client_phone'],
        'amount': _toDouble(row['amount']),
        'payment_date': row['payment_date'],
        'receipt_number': row['receipt_number'],
        'affected_sales': jsonEncode(row['affected_sales']),
        'created_at': row['created_at'],
      };
    }).toList();
  }

  static Future<List<Map<String, dynamic>>> getPaymentHistoryBetweenDates(
    DateTime start,
    DateTime end,
  ) async {
    final rows = await SupabaseHelper.client
        .from('payment_history')
        .select()
        .gte('payment_date', start.toIso8601String())
        .lt('payment_date', end.add(const Duration(days: 1)).toIso8601String())
        .order('payment_date', ascending: false);

    return rows.map<Map<String, dynamic>>((row) {
      return {
        'id': row['local_id'],
        'client_phone': row['client_phone'],
        'amount': _toDouble(row['amount']),
        'payment_date': row['payment_date'],
        'receipt_number': row['receipt_number'],
        'affected_sales': jsonEncode(row['affected_sales']),
        'created_at': row['created_at'],
      };
    }).toList();
  }

  static Future<List<Map<String, dynamic>>> getExpenseHistory(
    DateTime start,
    DateTime end,
  ) async {
    final rows = await SupabaseHelper.client
        .from('expense_entries')
        .select('local_id,local_expense_id,amount,entry_date,expenses(name)')
        .filter('deleted_at', 'is', null)
        .gte('entry_date', start.toIso8601String())
        .lt('entry_date', end.add(const Duration(days: 1)).toIso8601String())
        .order('entry_date', ascending: false);

    final expensesById = {
      for (final expense in await getExpenses())
        if (expense.id != null) expense.id!: expense.name,
    };

    return rows.map<Map<String, dynamic>>((row) {
      final expense = row['expenses'];
      final localExpenseId = _toInt(row['local_expense_id']);
      final relatedName =
          expense is Map ? (expense['name'] ?? '').toString() : '';
      return {
        'id': row['local_id'],
        'expense_id': localExpenseId,
        'expense_name':
            relatedName.isNotEmpty
                ? relatedName
                : (expensesById[localExpenseId] ?? 'Gasto #$localExpenseId'),
        'amount': _toDouble(row['amount']),
        'date': row['entry_date']?.toString(),
      };
    }).toList();
  }

  static Future<List<Map<String, dynamic>>> getProductSalesByBusiness(
    String businessType,
    DateTime start,
    DateTime end,
  ) async {
    final rows = await _getSaleItemsWithRelations(start, end);
    final totals = <int, Map<String, dynamic>>{};

    for (final row in rows) {
      final product = row['products'];
      final sale = row['sales'];
      if (product is! Map || sale is! Map) continue;
      if (product['business_type'] != businessType) continue;
      if (_toBool(sale['is_voided'])) continue;

      final productId = _toInt(row['local_product_id']);
      final quantity = _toInt(row['quantity']);
      final subtotal = _toDouble(row['subtotal']);
      final discount = _toDouble(row['discount']);
      final cost = _toDouble(product['cost']);

      final bucket = totals.putIfAbsent(productId, () {
        return {
          'product_name': product['name']?.toString() ?? '',
          'total_quantity': 0,
          'total_discount': 0.0,
          'total_sales': 0.0,
          'total_gain': 0.0,
        };
      });

      bucket['total_quantity'] = (bucket['total_quantity'] as int) + quantity;
      bucket['total_discount'] =
          (bucket['total_discount'] as double) + (discount * quantity);
      bucket['total_sales'] = (bucket['total_sales'] as double) + subtotal;
      if (quantity > 0) {
        bucket['total_gain'] =
            (bucket['total_gain'] as double) +
            (((subtotal / quantity) - cost) * quantity);
      }
    }

    final result = totals.values.toList();
    result.sort(
      (a, b) =>
          (b['total_quantity'] as int).compareTo(a['total_quantity'] as int),
    );
    return result;
  }

  static Future<List<Map<String, dynamic>>> getRentableProductReport(
    DateTime start,
    DateTime end,
  ) async {
    final rows = await _getSaleItemsWithRelations(start, end);
    final totals = <int, Map<String, dynamic>>{};

    for (final row in rows) {
      final product = row['products'];
      final sale = row['sales'];
      if (product is! Map || sale is! Map) continue;
      if (product['is_rentable'] != true) continue;
      if (_toBool(sale['is_voided'])) continue;

      final productId = _toInt(row['local_product_id']);
      final quantity = _toInt(row['quantity']);
      final subtotal = _toDouble(row['subtotal']);
      final discount = _toDouble(row['discount']);

      final bucket = totals.putIfAbsent(productId, () {
        return {
          'product_name': product['name']?.toString() ?? '',
          'times_sold': 0,
          'total_income': 0.0,
          'total_discount': 0.0,
        };
      });

      bucket['times_sold'] = (bucket['times_sold'] as int) + 1;
      bucket['total_income'] = (bucket['total_income'] as double) + subtotal;
      bucket['total_discount'] =
          (bucket['total_discount'] as double) + (discount * quantity);
    }

    final result = totals.values.toList();
    result.sort(
      (a, b) =>
          (b['total_income'] as double).compareTo(a['total_income'] as double),
    );
    return result;
  }

  static Future<Map<String, dynamic>> getResumenGeneral(
    DateTime start,
    DateTime end,
  ) async {
    final salesRows = await SupabaseHelper.client
        .from('sales')
        .select()
        .gte('sale_date', start.toIso8601String())
        .lt('sale_date', end.add(const Duration(days: 1)).toIso8601String());

    final itemRows = await _getSaleItemsWithRelations(start, end);
    final inventoryRows = await SupabaseHelper.client
        .from('inventory_entries')
        .select()
        .gte('entry_date', start.toIso8601String())
        .lt('entry_date', end.add(const Duration(days: 1)).toIso8601String());
    final expenseRows = await SupabaseHelper.client
        .from('expense_entries')
        .select('amount')
        .filter('deleted_at', 'is', null)
        .gte('entry_date', start.toIso8601String())
        .lt('entry_date', end.add(const Duration(days: 1)).toIso8601String());

    final validSaleIds = <int>{};
    var totalFacturas = 0;
    var totalVentas = 0.0;
    var pagosCredito = 0.0;

    for (final sale in salesRows) {
      if (_toBool(sale['is_voided'])) continue;
      final localSaleId = _toInt(sale['local_id']);
      validSaleIds.add(localSaleId);
      totalFacturas++;
      final total = _toDouble(sale['total']);
      final amountDue = _toDouble(sale['amount_due']);
      totalVentas += total;
      if (_toBool(sale['is_credit'])) pagosCredito += total - amountDue;
    }

    var descuentos = 0.0;
    var ganancia = 0.0;
    var productosVendidos = 0;
    for (final item in itemRows) {
      if (!validSaleIds.contains(_toInt(item['local_sale_id']))) continue;
      final product = item['products'];
      if (product is! Map) continue;
      final quantity = _toInt(item['quantity']);
      if (quantity <= 0) continue;
      final subtotal = _toDouble(item['subtotal']);
      final discount = _toDouble(item['discount']);
      final cost = _toDouble(product['cost']);
      productosVendidos += quantity;
      descuentos += discount * quantity;
      ganancia += ((subtotal / quantity) - cost) * quantity;
    }

    final totalInventario = inventoryRows.fold<double>(0, (sum, row) {
      return sum + (_toDouble(row['cost']) * _toInt(row['quantity']));
    });
    final totalGastos = expenseRows.fold<double>(0, (sum, row) {
      return sum + _toDouble(row['amount']);
    });

    return {
      'facturas': totalFacturas,
      'ventas': totalVentas,
      'pagos_credito': pagosCredito,
      'descuentos': descuentos,
      'productos': productosVendidos,
      'inventario': totalInventario,
      'ganancia': ganancia,
      'gastos': totalGastos,
    };
  }

  static Future<void> syncExpense(Expense expense) async {
    final localId = expense.id;
    if (localId == null) return;

    await _safeSync(
      source: 'SupabaseSyncHelper.syncExpense',
      action:
          () => SupabaseHelper.client.from('expenses').upsert({
            'local_id': localId,
            'name': expense.name,
            'deleted_at': null,
          }, onConflict: 'local_id'),
    );
  }

  static Future<void> syncExpenseEntry(ExpenseEntry entry) async {
    final localId = entry.id;
    if (localId == null || localId <= 0) return;

    await _safeSync(
      source: 'SupabaseSyncHelper.syncExpenseEntry',
      action: () async {
        await SupabaseHelper.client.from('expense_entries').upsert({
          'local_id': localId,
          'expense_id': await _getUuidByLocalId('expenses', entry.expenseId),
          'local_expense_id': entry.expenseId,
          'amount': entry.amount,
          'entry_date': entry.date,
          'deleted_at': null,
        }, onConflict: 'local_id');
      },
    );
  }

  static Future<void> syncInventoryDraft({
    required String draftKey,
    required String payload,
    required String updatedAt,
  }) async {
    await _safeSync(
      source: 'SupabaseSyncHelper.syncInventoryDraft',
      action:
          () => SupabaseHelper.client.from('inventory_drafts').upsert({
            'draft_key': draftKey,
            'payload': _jsonOrNull(payload),
            'updated_at': updatedAt,
          }, onConflict: 'draft_key'),
    );
  }

  static Future<String?> getInventoryDraft(String draftKey) async {
    final rows = await SupabaseHelper.client
        .from('inventory_drafts')
        .select('payload')
        .eq('draft_key', draftKey)
        .limit(1);

    if (rows.isEmpty) return null;
    final payload = rows.first['payload'];
    if (payload == null) return null;
    if (payload is String) return payload;
    return jsonEncode(payload);
  }

  static Future<void> deleteInventoryDraft(String draftKey) async {
    await _safeSync(
      source: 'SupabaseSyncHelper.deleteInventoryDraft',
      action:
          () => SupabaseHelper.client
              .from('inventory_drafts')
              .delete()
              .eq('draft_key', draftKey),
    );
  }

  static Future<void> syncSupplier(Supplier supplier) async {
    final localId = supplier.id;
    if (localId == null) return;

    await _safeSync(
      source: 'SupabaseSyncHelper.syncSupplier',
      action:
          () => SupabaseHelper.client.from('suppliers').upsert({
            'local_id': localId,
            'name': supplier.name,
            'phone': supplier.phone,
            'description': supplier.description,
            'address': supplier.address,
            'email': supplier.email,
            'deleted_at': null,
          }, onConflict: 'local_id'),
    );
  }

  static Future<void> syncClient(Client client) async {
    final localId = client.id;
    if (localId == null) return;

    await _safeSync(
      source: 'SupabaseSyncHelper.syncClient',
      action:
          () => SupabaseHelper.client.from('clients').upsert({
            'local_id': localId,
            'name': client.name,
            'last_name': client.lastName,
            'phone': client.phone,
            'address': client.address,
            'email': client.email,
            'has_credit': client.hasCredit,
            'credit_limit': client.creditLimit,
            'credit': client.credit,
            'credit_available': client.creditAvailable,
            'deleted_at': null,
          }, onConflict: 'local_id'),
    );
  }

  static Future<void> syncProduct(Product product) async {
    final localId = product.id;
    if (localId == null) return;

    await _safeSync(
      source: 'SupabaseSyncHelper.syncProduct',
      action: () async {
        final supplierUuid = await _getSupplierUuid(product.supplierId);
        await SupabaseHelper.client.from('products').upsert({
          'local_id': localId,
          'supplier_id': supplierUuid,
          'local_supplier_id': product.supplierId,
          'name': product.name,
          'barcode': product.barcode,
          'description': product.description,
          'business_type': product.businessType,
          'price': product.price,
          'quantity': product.quantity,
          'cost': product.cost,
          'is_rentable': product.isRentable == true,
          'original_created_at': product.createdAt,
          'deleted_at': null,
        }, onConflict: 'local_id');
      },
    );
  }

  static Future<void> syncInventoryEntry(Map<String, dynamic> entry) async {
    final localId = _toInt(entry['id']);
    if (localId <= 0) return;

    await _safeSync(
      source: 'SupabaseSyncHelper.syncInventoryEntry',
      action: () async {
        final localProductId = _toInt(entry['product_id']);
        final localSupplierId = _toInt(entry['supplier_id']);
        await SupabaseHelper.client.from('inventory_entries').upsert({
          'local_id': localId,
          'product_id': await _getUuidByLocalId('products', localProductId),
          'supplier_id': await _getUuidByLocalId('suppliers', localSupplierId),
          'local_product_id': localProductId,
          'local_supplier_id': localSupplierId,
          'quantity': _toInt(entry['quantity']),
          'cost': _toDouble(entry['cost']),
          'entry_date': entry['date']?.toString(),
          'deleted_at': null,
        }, onConflict: 'local_id');
      },
    );
  }

  static Future<void> syncSale(Map<String, dynamic> sale) async {
    final localId = _toInt(sale['id']);
    if (localId <= 0) return;

    await _safeSync(
      source: 'SupabaseSyncHelper.syncSale',
      action: () async {
        final clientPhone = sale['clientPhone']?.toString();
        await SupabaseHelper.client.from('sales').upsert({
          'local_id': localId,
          'client_id': await _getClientUuidByPhone(clientPhone),
          'client_phone': clientPhone,
          'sale_date': sale['date']?.toString(),
          'total': _toDouble(sale['total']),
          'amount_due': _toDouble(sale['amountDue']),
          'is_credit': _toBool(sale['isCredit']),
          'is_paid': _toBool(sale['isPaid']),
          'is_voided': _toBool(sale['isVoided']),
          'voided_at': sale['voidedAt']?.toString(),
          'deleted_at': null,
        }, onConflict: 'local_id');
      },
    );
  }

  static Future<void> syncSaleItem(Map<String, dynamic> item) async {
    final localId = _toInt(item['id']);
    if (localId <= 0) return;

    await _safeSync(
      source: 'SupabaseSyncHelper.syncSaleItem',
      action: () async {
        final localSaleId = _toInt(item['sale_id']);
        final localProductId = _toInt(item['product_id']);
        await SupabaseHelper.client.from('sale_items').upsert({
          'local_id': localId,
          'sale_id': await _getUuidByLocalId('sales', localSaleId),
          'product_id': await _getUuidByLocalId('products', localProductId),
          'local_sale_id': localSaleId,
          'local_product_id': localProductId,
          'quantity': _toInt(item['quantity']),
          'subtotal': _toDouble(item['subtotal']),
          'discount': _toDouble(item['discount']),
          'deleted_at': null,
        }, onConflict: 'local_id');
      },
    );
  }

  static Future<void> syncPaymentHistory(Map<String, dynamic> payment) async {
    final localId = _toInt(payment['id']);
    if (localId <= 0) return;

    await _safeSync(
      source: 'SupabaseSyncHelper.syncPaymentHistory',
      action: () async {
        final clientPhone = payment['client_phone']?.toString();
        await SupabaseHelper.client.from('payment_history').upsert({
          'local_id': localId,
          'client_id': await _getClientUuidByPhone(clientPhone),
          'client_phone': clientPhone,
          'amount': _toDouble(payment['amount']),
          'payment_date': payment['payment_date']?.toString(),
          'receipt_number': payment['receipt_number']?.toString(),
          'affected_sales': _jsonOrNull(payment['affected_sales']),
          'created_at': payment['created_at']?.toString(),
          'deleted_at': null,
        }, onConflict: 'local_id');
      },
    );
  }

  static Future<void> markDeleted(String table, int localId) async {
    await _safeSync(
      source: 'SupabaseSyncHelper.markDeleted.$table',
      action:
          () => SupabaseHelper.client
              .from(table)
              .update({'deleted_at': DateTime.now().toIso8601String()})
              .eq('local_id', localId),
    );
  }

  static Future<void> _safeSync({
    required String source,
    required Future<void> Function() action,
  }) async {
    try {
      await action();
    } catch (error, stackTrace) {
      await ErrorLogger.log(
        source: source,
        error: error,
        stackTrace: stackTrace,
        details:
            'La operacion local se guardo, pero no se pudo sincronizar con Supabase.',
      );
    }
  }

  static Future<List<dynamic>> _getSaleItemsWithRelations(
    DateTime start,
    DateTime end,
  ) async {
    return await SupabaseHelper.client
        .from('sale_items')
        .select(
          'local_sale_id,local_product_id,quantity,subtotal,discount,'
          'products(name,cost,business_type,is_rentable),'
          'sales(sale_date,is_voided)',
        )
        .gte('sales.sale_date', start.toIso8601String())
        .lt(
          'sales.sale_date',
          end.add(const Duration(days: 1)).toIso8601String(),
        );
  }

  static double _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int _toInt(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static bool _toBool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value.toInt() == 1;
    return value?.toString() == '1' || value?.toString() == 'true';
  }

  static Object? _jsonOrNull(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    try {
      return jsonDecode(text);
    } catch (_) {
      return {'raw': text};
    }
  }

  static Future<String?> _getUuidByLocalId(String table, int localId) async {
    if (localId <= 0) return null;

    final rows = await SupabaseHelper.client
        .from(table)
        .select('id')
        .eq('local_id', localId)
        .limit(1);

    if (rows.isEmpty) return null;
    return rows.first['id']?.toString();
  }

  static Future<String?> _getClientUuidByPhone(String? phone) async {
    final normalizedPhone = phone?.trim();
    if (normalizedPhone == null || normalizedPhone.isEmpty) return null;

    final rows = await SupabaseHelper.client
        .from('clients')
        .select('id')
        .eq('phone', normalizedPhone)
        .limit(1);

    if (rows.isEmpty) return null;
    return rows.first['id']?.toString();
  }

  static Future<String?> _getSupplierUuid(int localSupplierId) async {
    return _getUuidByLocalId('suppliers', localSupplierId);
  }

  static Map<String, dynamic> _saleToLocalMap(Map<String, dynamic> row) {
    return {
      'id': row['local_id'],
      'date': row['sale_date'],
      'total': _toDouble(row['total']),
      'amountDue': _toDouble(row['amount_due']),
      'clientPhone': row['client_phone'],
      'isCredit': _toBool(row['is_credit']) ? 1 : 0,
      'isPaid': _toBool(row['is_paid']) ? 1 : 0,
      'isVoided': _toBool(row['is_voided']) ? 1 : 0,
      'voidedAt': row['voided_at'],
    };
  }

  static Map<String, dynamic> _saleItemToLocalMap(Map<String, dynamic> row) {
    return {
      'id': row['local_id'],
      'sale_id': row['local_sale_id'],
      'product_id': row['local_product_id'],
      'quantity': _toInt(row['quantity']),
      'subtotal': _toDouble(row['subtotal']),
      'discount': _toDouble(row['discount']),
    };
  }
}
