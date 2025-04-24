import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/db_helper.dart';
import '../models/sale.dart';
import '../models/supplier.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  String _reportType = 'facturacion';
  Supplier? _selectedSupplier;
  List<Supplier> _suppliers = [];
  List<Sale> _filteredSales = [];

  double creditTotal = 0;
  double cashTotal = 0;
  double profitTotal = 0;
  double creditPaymentsTotal = 0;
  double totalDiscounts = 0;

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
  }

  Future<void> _loadSuppliers() async {
    final result = await DBHelper.getSuppliers();
    setState(() {
      _suppliers = result;
    });
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _generateReport() async {
    if (_startDate == null || _endDate == null) return;

    switch (_reportType) {
      case 'facturacion':
        await _generateFacturacionReport();
        break;
      case 'inventario':
        await _generateInventarioReport();
        break;
      case 'pagos_credito':
        await _generatePagosCreditoReport();
        break;
      case 'historial_gastos':
        await _generateGastosReport();
        break;
      case 'resumen_general':
        await _generateResumenGeneralReport();
        break;
      case 'facturas_cliente':
        await _generateFacturasClienteReport();
        break;
      case 'productos_negocio':
        await _generateProductosPorNegocioReport();
        break;
      case 'rentables':
        await _generateRentablesReport();
        break;
      default:
        break;
    }
  }

  Future<void> _generateRentablesReport() async {
  final data = await DBHelper.getRentableProductReport(_startDate!, _endDate!);

  int totalArticulos = 0;
  double totalDescuento = 0;
  double totalIngreso = 0;

  for (var row in data) {
    totalArticulos += row['times_sold'] as int;
    totalDescuento += row['total_discount'] as double;
    totalIngreso += row['total_income'] as double;
  }

  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Reporte de Productos Rentables'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rango: ${DateFormat('yyyy-MM-dd').format(_startDate!)} a ${DateFormat('yyyy-MM-dd').format(_endDate!)}'),
            const Divider(),
            ...data.map((row) => ListTile(
              title: Text(row['product_name']),
              subtitle: Text(
                'Veces alquilado: ${row['times_sold']}  |  Descuento total: \$${(row['total_discount'] as double).toStringAsFixed(2)}',
              ),
              trailing: Text('\$${(row['total_income'] as double).toStringAsFixed(2)}'),
            )),
            const Divider(),
            Text('🔁 Total de artículos alquilados: $totalArticulos'),
            Text('💸 Total de descuentos: \$${totalDescuento.toStringAsFixed(2)}'),
            Text('💰 Total de ingresos: \$${totalIngreso.toStringAsFixed(2)}'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    ),
  );
}


  Future<void> _generateFacturasClienteReport() async {
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Buscar Cliente'),
            content: TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Número de Teléfono del Cliente',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final phone = phoneController.text.trim();
                  Navigator.pop(context);

                  final facturas = await DBHelper.getFacturasPorCliente(
                    phone,
                    _startDate!,
                    _endDate!,
                  );
                  final cliente = await DBHelper.getClientByPhone(phone);

                  final nombreCliente =
                      cliente != null
                          ? '${cliente.name} ${cliente.lastName}'
                          : 'Cliente desconocido';

                  if (facturas.isEmpty) {
                    showDialog(
                      context: context,
                      builder:
                          (_) => AlertDialog(
                            title: const Text('Sin resultados'),
                            content: const Text(
                              'No se encontraron facturas para este cliente en el rango seleccionado.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cerrar'),
                              ),
                            ],
                          ),
                    );
                    return;
                  }

                  int countCredito = 0;
                  int countContado = 0;
                  double totalCredito = 0;
                  double totalContado = 0;
                  double totalPagado = 0;
                  double totalDeuda = 0;

                  for (var f in facturas) {
                    final total = f['total'] as double;
                    final deuda = f['amountDue'] as double;
                    final pagado = total - deuda;
                    final esCredito = f['isCredit'] == 1;

                    if (esCredito) {
                      countCredito++;
                      totalCredito += total;
                      totalPagado += pagado;
                      totalDeuda += deuda;
                    } else {
                      countContado++;
                      totalContado += total;
                    }
                  }

                  showDialog(
                    context: context,
                    builder:
                        (_) => AlertDialog(
                          title: const Text('Facturación por Cliente'),
                          content: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Cliente: $nombreCliente ($phone)'),
                                Text(
                                  'Rango: ${DateFormat('yyyy-MM-dd').format(_startDate!)} a ${DateFormat('yyyy-MM-dd').format(_endDate!)}',
                                ),
                                const Divider(),
                                ...facturas.map((f) {
                                  final total = f['total'] as double;
                                  final deuda = f['amountDue'] as double;
                                  final pagado = total - deuda;
                                  final isCredito = f['isCredit'] == 1;
                                  final estado =
                                      isCredito
                                          ? (deuda == 0
                                              ? 'PAGADA ✅'
                                              : 'PENDIENTE ❗')
                                          : '';

                                  return ListTile(
                                    title: Text('Factura #${f['id']}'),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Fecha: ${DateFormat('yyyy-MM-dd').format(DateTime.parse(f['date']))}',
                                        ),
                                        Text(
                                          'Tipo: ${isCredito ? 'Crédito ($estado)' : 'Contado'}',
                                        ),
                                        if (isCredito)
                                          Text(
                                            'Pagado: \$${pagado.toStringAsFixed(2)}',
                                          ),
                                      ],
                                    ),
                                    trailing: Text(
                                      '\$${total.toStringAsFixed(2)}',
                                    ),
                                  );
                                }),
                                const Divider(),
                                Text(
                                  'Cantidad de Facturas a Crédito: $countCredito',
                                ),
                                Text(
                                  'Cantidad de Facturas al Contado: $countContado',
                                ),
                                Text(
                                  'Total Facturado a Crédito: \$${totalCredito.toStringAsFixed(2)}',
                                ),
                                Text(
                                  'Total Facturado al Contado: \$${totalContado.toStringAsFixed(2)}',
                                ),
                                Text(
                                  'Total Pagado (Crédito): \$${totalPagado.toStringAsFixed(2)}',
                                ),
                                Text(
                                  'Total Adeudado: \$${totalDeuda.toStringAsFixed(2)}',
                                ),
                              ],
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cerrar'),
                            ),
                          ],
                        ),
                  );
                },
                child: const Text('Buscar'),
              ),
            ],
          ),
    );
  }

  Future<void> _generateResumenGeneralReport() async {
    final data = await DBHelper.getResumenGeneral(_startDate!, _endDate!);

    final double gananciaBruta = data['ganancia'] as double;
    final double gastos = data['gastos'] as double;
    final double gananciaNeta = gananciaBruta - gastos;

    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Resumen General'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rango: ${DateFormat('yyyy-MM-dd').format(_startDate!)} a ${DateFormat('yyyy-MM-dd').format(_endDate!)}',
                  ),
                  const Divider(),
                  Text('🧾 Facturas generadas: ${data['facturas']}'),
                  Text(
                    '💰 Total Ventas: \$${(data['ventas'] as double).toStringAsFixed(2)}',
                  ),
                  Text(
                    '🪙 Pagos a Crédito: \$${(data['pagos_credito'] as double).toStringAsFixed(2)}',
                  ),
                  Text(
                    '💸 Descuentos Aplicados: \$${(data['descuentos'] as double).toStringAsFixed(2)}',
                  ),
                  Text('📦 Productos Vendidos: ${data['productos']}'),
                  Text(
                    '📥 Ingreso Inventario: \$${(data['inventario'] as double).toStringAsFixed(2)}',
                  ),
                  Text('📉 Gastos: \$${gastos.toStringAsFixed(2)}'),
                  Text(
                    '📊 Ganancia Estimada: \$${gananciaBruta.toStringAsFixed(2)}',
                  ),
                  const Divider(),
                  Text(
                    '💼 Ganancia Neta: \$${gananciaNeta.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
            ],
          ),
    );
  }

  Future<void> _generateProductosPorNegocioReport() async {
    String? negocioSeleccionado;

    await showDialog(
      context: context,
      builder: (_) {
        String? tempNegocio;
        return AlertDialog(
          title: const Text('Seleccionar Negocio'),
          content: DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'Negocio'),
            items: const [
              DropdownMenuItem(value: 'Decoyamix', child: Text('Decoyamix')),
              DropdownMenuItem(value: 'EnmaYami', child: Text('EnmaYami')),
              DropdownMenuItem(
                value: 'Decoyamix(hogar)',
                child: Text('Decoyamix(hogar)'),
              ),
            ],
            onChanged: (val) {
              tempNegocio = val;
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                negocioSeleccionado = tempNegocio;
                Navigator.pop(context);
              },
              child: const Text('Ver Reporte'),
            ),
          ],
        );
      },
    );

    if (negocioSeleccionado == null) return;

    final data = await DBHelper.getProductSalesByBusiness(
      negocioSeleccionado!,
      _startDate!,
      _endDate!,
    );

    int totalCantidad = 0;
    double totalDescuento = 0;
    double totalVentas = 0;
    double totalGanancia = 0;

    for (var row in data) {
      totalCantidad += row['total_quantity'] as int;
      totalDescuento += row['total_discount'] as double;
      totalVentas += row['total_sales'] as double;
      totalGanancia += row['total_gain'] as double;
    }

    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text('Productos Vendidos - $negocioSeleccionado'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rango: ${DateFormat('yyyy-MM-dd').format(_startDate!)} a ${DateFormat('yyyy-MM-dd').format(_endDate!)}',
                  ),
                  const Divider(),
                  ...data.map(
                    (row) => ListTile(
                      title: Text(row['product_name']),
                      subtitle: Text(
                        'Cantidad: ${row['total_quantity']} - Descuento: \$${(row['total_discount'] as double).toStringAsFixed(2)}',
                      ),
                      trailing: Text(
                        '\$${(row['total_sales'] as double).toStringAsFixed(2)}',
                      ),
                    ),
                  ),
                  const Divider(),
                  Text('🧾 Total Productos Vendidos: $totalCantidad'),
                  Text(
                    '💸 Total Descuentos: \$${totalDescuento.toStringAsFixed(2)}',
                  ),
                  Text('💰 Total Ventas: \$${totalVentas.toStringAsFixed(2)}'),
                  Text(
                    '📊 Total Ganancia: \$${totalGanancia.toStringAsFixed(2)}',
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
            ],
          ),
    );
  }

  Future<void> _generateFacturacionReport() async {
    final sales = await DBHelper.getAllSales();
    final filtered =
        sales.where((s) {
          final saleDate = DateTime.parse(s.date);
          return saleDate.isAfter(
                _startDate!.subtract(const Duration(days: 1)),
              ) &&
              saleDate.isBefore(_endDate!.add(const Duration(days: 1)));
        }).toList();

    double credit = 0;
    double cash = 0;
    double profit = 0;
    double payments = 0;
    double discounts = 0;

    for (var s in filtered) {
      final items = await DBHelper.getSaleItems(s.id!);

      double discountAmount = 0;
      for (var item in items) {
        discountAmount += item.discount * item.quantity;
      }

      if (s.isCredit) {
        credit += s.total;
        final paid = s.total - s.amountDue;
        payments += paid;
      } else {
        cash += s.total;
      }

      for (var item in items) {
        final product = await DBHelper.getProductById(item.productId);
        final cost = product?.cost ?? 0;
        final gain = ((item.subtotal / item.quantity) - cost) * item.quantity;
        profit += gain;
      }

      s.discount = discountAmount;
      discounts += discountAmount;
    }

    setState(() {
      _filteredSales = filtered;
      creditTotal = credit;
      cashTotal = cash;
      creditPaymentsTotal = payments;
      profitTotal = profit;
      totalDiscounts = discounts;
    });

    _showSalesPreview();
  }

  Future<void> _generateGastosReport() async {
    final gastos = await DBHelper.getExpenseHistory(_startDate!, _endDate!);

    final totalGastos = gastos.fold<double>(
      0.0,
      (sum, g) => sum + (g['amount'] as double),
    );

    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Historial de Gastos'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rango: ${DateFormat('yyyy-MM-dd').format(_startDate!)} a ${DateFormat('yyyy-MM-dd').format(_endDate!)}',
                  ),
                  Text(
                    'Fecha de Generación: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}',
                  ),
                  const Divider(),
                  ...gastos.map(
                    (gasto) => ListTile(
                      title: Text(gasto['expense_name']),
                      subtitle: Text(
                        'Fecha: ${DateFormat('yyyy-MM-dd').format(DateTime.parse(gasto['date']))}',
                      ),
                      trailing: Text(
                        '\$${(gasto['amount'] as double).toStringAsFixed(2)}',
                      ),
                    ),
                  ),
                  const Divider(),
                  Text('Total Gastado: \$${totalGastos.toStringAsFixed(2)}'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
            ],
          ),
    );
  }

  Future<void> _generateInventarioReport() async {
    if (_selectedSupplier == null) return;

    final entries = await DBHelper.getInventoryEntriesBySupplierAndDate(
      _selectedSupplier!.id!,
      _startDate!,
      _endDate!,
    );

    final products = await DBHelper.getProducts();
    final productMap = {for (var p in products) p.id!: p};

    final totalQty = entries.fold<int>(
      0,
      (sum, e) => sum + (e['quantity'] as int),
    );
    final totalCost = entries.fold<double>(
      0.0,
      (sum, e) => sum + ((e['cost'] as num) * (e['quantity'] as int)),
    );

    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Reporte de Inventario'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Proveedor: ${_selectedSupplier!.name}'),
                  Text(
                    'Rango: ${DateFormat('yyyy-MM-dd').format(_startDate!)} - ${DateFormat('yyyy-MM-dd').format(_endDate!)}',
                  ),
                  Text(
                    'Generado: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}',
                  ),
                  const Divider(),
                  ...entries.map((e) {
                    final product = productMap[e['product_id']]!;
                    final quantity = e['quantity'];
                    final cost = e['cost'];
                    final total = (cost * quantity).toStringAsFixed(2);

                    return ListTile(
                      title: Text(product.name),
                      subtitle: Text(
                        'Cantidad: $quantity  |  Costo: \$${cost.toStringAsFixed(2)}',
                      ),
                      trailing: Text('Total: \$${total}'),
                    );
                  }),
                  const Divider(),
                  Text('Cantidad Total: $totalQty'),
                  Text('Costo Total: \$${totalCost.toStringAsFixed(2)}'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
            ],
          ),
    );
  }

  Future<void> _generatePagosCreditoReport() async {
    final sales = await DBHelper.getAllSales();
    final filtered =
        sales.where((s) {
          final saleDate = DateTime.parse(s.date);
          return s.isCredit &&
              s.amountDue < s.total &&
              saleDate.isAfter(_startDate!.subtract(const Duration(days: 1))) &&
              saleDate.isBefore(_endDate!.add(const Duration(days: 1)));
        }).toList();

    double totalPagado = 0;
    final List<Map<String, dynamic>> detalles = [];

    for (var sale in filtered) {
      final cliente = await DBHelper.getClientByPhone(sale.clientPhone ?? '');
      final nombreCliente =
          cliente != null
              ? '${cliente.name} ${cliente.lastName}'
              : 'Desconocido';
      final pagado = sale.total - sale.amountDue;

      totalPagado += pagado;
      detalles.add({
        'fecha': sale.date,
        'cliente': nombreCliente,
        'monto': pagado,
      });
    }

    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Pagos a Crédito Recibidos'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rango del Reporte: ${DateFormat('yyyy-MM-dd').format(_startDate!)} a ${DateFormat('yyyy-MM-dd').format(_endDate!)}',
                  ),
                  const SizedBox(height: 10),
                  ...detalles.map(
                    (d) => ListTile(
                      title: Text(d['cliente']),
                      subtitle: Text(
                        'Fecha: ${DateFormat('yyyy-MM-dd').format(DateTime.parse(d['fecha']))}',
                      ),
                      trailing: Text('\$${d['monto'].toStringAsFixed(2)}'),
                    ),
                  ),
                  const Divider(),
                  Text('Total Pagado: \$${totalPagado.toStringAsFixed(2)}'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
            ],
          ),
    );
  }

  void _showSalesPreview() {
    final total = creditTotal + cashTotal;
    final now = DateTime.now();
    final format = DateFormat('yyyy-MM-dd HH:mm:ss');

    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Reporte de Facturación'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rango del Reporte: ${DateFormat('yyyy-MM-dd').format(_startDate!)} a ${DateFormat('yyyy-MM-dd').format(_endDate!)}',
                  ),
                  Text('Fecha de Generación: ${format.format(now)}'),
                  const Divider(),
                  const Text(
                    '🧾 Facturas:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  ..._filteredSales.map(
                    (sale) => ListTile(
                      title: Text('Factura #${sale.id}'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Fecha: ${DateFormat('yyyy-MM-dd').format(DateTime.parse(sale.date))}',
                          ),
                          Text(
                            'Tipo: ${sale.isCredit ? "Crédito" : "Contado"}',
                          ),
                          if ((sale.discount ?? 0) > 0)
                            Text(
                              'Descuento: \$${sale.discount!.toStringAsFixed(2)}',
                            ),
                        ],
                      ),
                      trailing: Text('\$${sale.total.toStringAsFixed(2)}'),
                    ),
                  ),
                  const Divider(),
                  Text('Cantidad de Facturas: ${_filteredSales.length}'),
                  Text(
                    'Total en Ventas a Crédito: \$${creditTotal.toStringAsFixed(2)}',
                  ),
                  Text(
                    'Total en Ventas al Contado: \$${cashTotal.toStringAsFixed(2)}',
                  ),
                  Text(
                    'Total General de Ventas: \$${total.toStringAsFixed(2)}',
                  ),
                  Text(
                    'Pagos realizados a facturas a crédito: \$${creditPaymentsTotal.toStringAsFixed(2)}',
                  ),
                  Text(
                    'Total Descuentos Aplicados: \$${totalDiscounts.toStringAsFixed(2)}',
                  ),
                  Text('Ganancia Total: \$${profitTotal.toStringAsFixed(2)}'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd');
    return Scaffold(
      appBar: AppBar(title: const Text('Reportes')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Tipo de Reporte'),
              value: _reportType,
              items: const [
                DropdownMenuItem(
                  value: 'facturacion',
                  child: Text('Facturación'),
                ),
                DropdownMenuItem(
                  value: 'inventario',
                  child: Text('Inventario por proveedor'),
                ),
                DropdownMenuItem(
                  value: 'pagos_credito',
                  child: Text('Pagos a Crédito Recibidos'),
                ),
                DropdownMenuItem(
                  value: 'historial_gastos',
                  child: Text('Historial de Gastos'),
                ),
                DropdownMenuItem(
                  value: 'productos_negocio',
                  child: Text('Productos Vendidos por Negocio'),
                ),
                DropdownMenuItem(
                  value: 'rentables',
                  child: Text('Productos Rentables'),
                ),
                DropdownMenuItem(
                  value: 'resumen_general',
                  child: Text('Resumen General'),
                ),
                DropdownMenuItem(
                  value: 'facturas_cliente',
                  child: Text('Facturación por Cliente'),
                ),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _reportType = val;
                  });
                }
              },
            ),

            const SizedBox(height: 16),
            if (_reportType == 'inventario') ...[
              DropdownButtonFormField<Supplier>(
                decoration: const InputDecoration(labelText: 'Proveedor'),
                value: _selectedSupplier,
                items:
                    _suppliers
                        .map(
                          (s) =>
                              DropdownMenuItem(value: s, child: Text(s.name)),
                        )
                        .toList(),
                onChanged: (val) => setState(() => _selectedSupplier = val),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _selectDate(context, true),
                    child: Text(
                      _startDate == null
                          ? 'Desde'
                          : dateFormat.format(_startDate!),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _selectDate(context, false),
                    child: Text(
                      _endDate == null ? 'Hasta' : dateFormat.format(_endDate!),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _generateReport,
              icon: const Icon(Icons.analytics),
              label: const Text('Generar Reporte'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
