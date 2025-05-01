import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/db_helper.dart';
import '../models/sale.dart';
import '../models/supplier.dart';
import '../models/client.dart';
import '../helpers/printer_helper.dart'; // Asegúrate de tener este import

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
  
  // Variables para almacenar los datos del último reporte generado
  Map<String, dynamic> _lastReportData = {};
  String _lastReportTitle = '';
  String _lastReportType = '';

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
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Por favor, selecciona un rango de fechas')),
      );
      return;
    }

    // Limpiar datos de reporte anterior
    _lastReportData.clear();
    _lastReportTitle = '';
    _lastReportType = _reportType;

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
    final data = await DBHelper.getRentableProductReport(
      _startDate!,
      _endDate!,
    );

    int totalArticulos = 0;
    double totalDescuento = 0;
    double totalIngreso = 0;

    for (var row in data) {
      totalArticulos += row['times_sold'] as int;
      totalDescuento += row['total_discount'] as double;
      totalIngreso += row['total_income'] as double;
    }

    // Guardar datos para impresión
    _lastReportTitle = 'Reporte de Productos Rentables';
    _lastReportData = {
      'data': data,
      'totalArticulos': totalArticulos,
      'totalDescuento': totalDescuento,
      'totalIngreso': totalIngreso,
      'startDate': _startDate,
      'endDate': _endDate,
    };

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(_lastReportTitle),
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
                    'Veces alquilado: ${row['times_sold']}  |  Descuento total: \$${(row['total_discount'] as double).toStringAsFixed(2)}',
                  ),
                  trailing: Text(
                    '\$${(row['total_income'] as double).toStringAsFixed(2)}',
                  ),
                ),
              ),
              const Divider(),
              Text('🔁 Total de artículos alquilados: $totalArticulos'),
              Text(
                '💸 Total de descuentos: \$${totalDescuento.toStringAsFixed(2)}',
              ),
              Text(
                '💰 Total de ingresos: \$${totalIngreso.toStringAsFixed(2)}',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          ElevatedButton.icon(
            icon: Icon(Icons.print),
            label: Text('Imprimir'),
            onPressed: () => _printLastReport(),
          ),
        ],
      ),
    );
  }

  Future<void> _generateFacturasClienteReport() async {
    final clients = await DBHelper.getClients();
    Client? selectedClient;
    final searchController = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) {
        List<Client> filteredClients = List.from(clients);

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Seleccionar Cliente'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: searchController,
                    decoration: const InputDecoration(
                      labelText: 'Buscar por nombre',
                    ),
                    onChanged: (value) {
                      setState(() {
                        filteredClients =
                            clients.where(
                                  (c) =>
                                      c.name.toLowerCase().contains(
                                        value.toLowerCase(),
                                      ) ||
                                      c.lastName.toLowerCase().contains(
                                        value.toLowerCase(),
                                      ),
                                )
                                .toList();
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 200,
                    width: double.maxFinite,
                    child: ListView.builder(
                      itemCount: filteredClients.length,
                      itemBuilder: (context, index) {
                        final client = filteredClients[index];
                        return ListTile(
                          title: Text('${client.name} ${client.lastName}'),
                          subtitle: Text(client.phone),
                          onTap: () {
                            selectedClient = client;
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (selectedClient == null) return;

    final phone = selectedClient!.phone;
    final facturas = await DBHelper.getFacturasPorCliente(
      phone,
      _startDate!,
      _endDate!,
    );
    final cliente = selectedClient;

    final nombreCliente =
        '${cliente?.name ?? "Desconocido"} ${cliente?.lastName ?? ""}';

    if (facturas.isEmpty) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
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

    // Guardar datos para impresión
    _lastReportTitle = 'Facturación por Cliente';
    _lastReportData = {
      'cliente': cliente,
      'nombreCliente': nombreCliente,
      'facturas': facturas,
      'countCredito': countCredito,
      'countContado': countContado,
      'totalCredito': totalCredito,
      'totalContado': totalContado,
      'totalPagado': totalPagado,
      'totalDeuda': totalDeuda,
      'startDate': _startDate,
      'endDate': _endDate,
    };
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
            title: Text(_lastReportTitle),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cliente: $nombreCliente'),
                  Text('Teléfono: ${cliente?.phone ?? "Sin teléfono"}'),
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
                            ? (deuda == 0 ? 'PAGADA ✅' : 'PENDIENTE ❗')
                            : '';

                    return ListTile(
                      title: Text('Factura #${f['id']}'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Fecha: ${DateFormat('yyyy-MM-dd').format(DateTime.parse(f['date']))}',
                          ),
                          Text(
                            'Tipo: ${isCredito ? 'Crédito ($estado)' : 'Contado'}',
                          ),
                          if (isCredito)
                            Text('Pagado: \$${pagado.toStringAsFixed(2)}'),
                        ],
                      ),
                      trailing: Text('\$${total.toStringAsFixed(2)}'),
                    );
                  }),
                  const Divider(),
                  Text('Cantidad de Facturas a Crédito: $countCredito'),
                  Text('Cantidad de Facturas al Contado: $countContado'),
                  Text(
                    'Total Facturado a Crédito: \$${totalCredito.toStringAsFixed(2)}',
                  ),
                  Text(
                    'Total Facturado al Contado: \$${totalContado.toStringAsFixed(2)}',
                  ),
                  Text(
                    'Total Pagado (Crédito): \$${totalPagado.toStringAsFixed(2)}',
                  ),
                  Text('Total Adeudado: \$${totalDeuda.toStringAsFixed(2)}'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
              ElevatedButton.icon(
                icon: Icon(Icons.print),
                label: Text('Imprimir'),
                onPressed: () => _printLastReport(),
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

    // Guardar datos para impresión
    _lastReportTitle = 'Resumen General';
    _lastReportData = {
      'data': data,
      'gananciaBruta': gananciaBruta,
      'gastos': gastos,
      'gananciaNeta': gananciaNeta,
      'startDate': _startDate,
      'endDate': _endDate,
    };

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
            title: Text(_lastReportTitle),
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
              ElevatedButton.icon(
                icon: Icon(Icons.print),
                label: Text('Imprimir'),
                onPressed: () => _printLastReport(),
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

    // Guardar datos para impresión
    _lastReportTitle = 'Productos Vendidos - $negocioSeleccionado';
    _lastReportData = {
      'negocio': negocioSeleccionado,
      'data': data,
      'totalCantidad': totalCantidad,
      'totalDescuento': totalDescuento,
      'totalVentas': totalVentas,
      'totalGanancia': totalGanancia,
      'startDate': _startDate,
      'endDate': _endDate,
    };

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
            title: Text(_lastReportTitle),
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
              ElevatedButton.icon(
                icon: Icon(Icons.print),
                label: Text('Imprimir'),
                onPressed: () => _printLastReport(),
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

    // Guardar datos para impresión
    _lastReportTitle = 'Reporte de Facturación';
    _lastReportData = {
      'sales': _filteredSales,
      'creditTotal': creditTotal,
      'cashTotal': cashTotal,
      'creditPaymentsTotal': creditPaymentsTotal,
      'profitTotal': profitTotal,
      'totalDiscounts': totalDiscounts,
      'startDate': _startDate,
      'endDate': _endDate,
    };

    _showSalesPreview();
  }
  Future<void> _generateGastosReport() async {
    final gastos = await DBHelper.getExpenseHistory(_startDate!, _endDate!);

    final totalGastos = gastos.fold<double>(
      0.0,
      (sum, g) => sum + (g['amount'] as double),
    );

    // Guardar datos para impresión
    _lastReportTitle = 'Historial de Gastos';
    _lastReportData = {
      'gastos': gastos,
      'totalGastos': totalGastos,
      'startDate': _startDate,
      'endDate': _endDate,
    };

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
            title: Text(_lastReportTitle),
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
              ElevatedButton.icon(
                icon: Icon(Icons.print),
                label: Text('Imprimir'),
                onPressed: () => _printLastReport(),
              ),
            ],
          ),
    );
  }

  Future<void> _generateInventarioReport() async {
    if (_selectedSupplier == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Por favor, selecciona un proveedor')),
      );
      return;
    }

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

    // Guardar datos para impresión
    _lastReportTitle = 'Reporte de Inventario';
    _lastReportData = {
      'supplier': _selectedSupplier,
      'entries': entries,
      'products': productMap,
      'totalQty': totalQty,
      'totalCost': totalCost,
      'startDate': _startDate,
      'endDate': _endDate,
    };

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
            title: Text(_lastReportTitle),
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
              ElevatedButton.icon(
                icon: Icon(Icons.print),
                label: Text('Imprimir'),
                onPressed: () => _printLastReport(),
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

    // Guardar datos para impresión
    _lastReportTitle = 'Pagos a Crédito Recibidos';
    _lastReportData = {
      'detalles': detalles,
      'totalPagado': totalPagado,
      'startDate': _startDate,
      'endDate': _endDate,
    };

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
            title: Text(_lastReportTitle),
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
              ElevatedButton.icon(
                icon: Icon(Icons.print),
                label: Text('Imprimir'),
                onPressed: () => _printLastReport(),
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
      builder: (_) => AlertDialog(
            title: Text(_lastReportTitle),
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
              ElevatedButton.icon(
                icon: Icon(Icons.print),
                label: Text('Imprimir'),
                onPressed: () => _printLastReport(),
              ),
            ],
          ),
    );
  }
  
  // Método para imprimir el último reporte generado
  Future<void> _printLastReport() async {
    if (_lastReportData.isEmpty || _lastReportTitle.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No hay reporte para imprimir')),
      );
      return;
    }
    
    try {
      // Mostrar indicador de progreso
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text("Imprimiendo reporte..."),
              ],
            ),
          );
        },
      );
      
      // Verificar conexión a la impresora
      final connected = await PrinterHelper.connectToPrinter();
      if (!connected) {
        Navigator.pop(context); // Cerrar diálogo de progreso
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo conectar a la impresora')),
        );
        return;
      }
      
      // Imprimir según el tipo de reporte
      await _printReportByType();
      
      // Cerrar diálogo de progreso
      Navigator.pop(context);
      
      // Mensaje de éxito
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reporte impreso correctamente')),
      );
    } catch (e) {
      // Cerrar diálogo de progreso si hay error
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      print('❌ Error al imprimir reporte: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al imprimir el reporte: $e')),
      );
    }
  }
  
  // Imprime el tipo de reporte específico
  Future<void> _printReportByType() async {
    switch (_lastReportType) {
      case 'facturacion':
        await _printFacturacionReport();
        break;
      case 'inventario':
        await _printInventarioReport();
        break;
      case 'pagos_credito':
        await _printPagosCreditoReport();
        break;
      case 'historial_gastos':
        await _printGastosReport();
        break;
      case 'resumen_general':
        await _printResumenGeneralReport();
        break;
      case 'facturas_cliente':
        await _printFacturasClienteReport();
        break;
      case 'productos_negocio':
        await _printProductosNegocioReport();
        break;
      case 'rentables':
        await _printRentablesReport();
        break;
      default:
        throw Exception('Tipo de reporte no implementado para impresión');
    }
  }
  
  // Métodos específicos para imprimir cada tipo de reporte
  Future<void> _printFacturacionReport() async {
    final sales = _lastReportData['sales'] as List<Sale>;
    final creditTotal = _lastReportData['creditTotal'] as double;
    final cashTotal = _lastReportData['cashTotal'] as double;
    final creditPaymentsTotal = _lastReportData['creditPaymentsTotal'] as double;
    final profitTotal = _lastReportData['profitTotal'] as double;
    final totalDiscounts = _lastReportData['totalDiscounts'] as double;
    final startDate = _lastReportData['startDate'] as DateTime;
    final endDate = _lastReportData['endDate'] as DateTime;
    final total = creditTotal + cashTotal;
    final now = DateTime.now();
    
    // Imprimir encabezado
    await PrinterHelper.bluetooth.printCustom("DECOYAMIX", 1, 1);
    await PrinterHelper.bluetooth.printCustom("REPORTE DE FACTURACIÓN", 1, 1);
    await PrinterHelper.bluetooth.printNewLine();
    
    // Fechas
    await PrinterHelper.bluetooth.printCustom("Periodo: ${DateFormat('yyyy-MM-dd').format(startDate)} a ${DateFormat('yyyy-MM-dd').format(endDate)}", 0, 0);
    await PrinterHelper.bluetooth.printCustom("Generado: ${DateFormat('yyyy-MM-dd HH:mm').format(now)}", 0, 0);
    await PrinterHelper.bluetooth.printCustom("--------------------------------", 0, 1);
    
    // Resumen
    await PrinterHelper.bluetooth.printCustom("RESUMEN DE FACTURACIÓN:", 0, 0);
    await PrinterHelper.bluetooth.printCustom("Facturas emitidas: ${sales.length}", 0, 0);
    await PrinterHelper.bluetooth.printCustom("Ventas a crédito: \$${creditTotal.toStringAsFixed(2)}", 0, 0);
    await PrinterHelper.bluetooth.printCustom("Ventas al contado: \$${cashTotal.toStringAsFixed(2)}", 0, 0);
    await PrinterHelper.bluetooth.printCustom("Total ventas: \$${total.toStringAsFixed(2)}", 0, 0);
    await PrinterHelper.bluetooth.printCustom("Pagos a crédito: \$${creditPaymentsTotal.toStringAsFixed(2)}", 0, 0);
    await PrinterHelper.bluetooth.printCustom("Descuentos: \$${totalDiscounts.toStringAsFixed(2)}", 0, 0);
    await PrinterHelper.bluetooth.printCustom("Ganancia: \$${profitTotal.toStringAsFixed(2)}", 0, 0);
    await PrinterHelper.bluetooth.printCustom("--------------------------------", 0, 1);
    
    // Detalle de facturas (limitado a 20 para no hacer el recibo muy largo)
    await PrinterHelper.bluetooth.printCustom("DETALLE DE FACTURAS:", 0, 0);
    int count = 0;
    for (var sale in sales) {
      if (count >= 20) {
        await PrinterHelper.bluetooth.printCustom("... y ${sales.length - 20} facturas más", 0, 0);
        break;
      }
      
      String line = "F#${sale.id} - ${DateFormat('MM/dd').format(DateTime.parse(sale.date))} - \$${sale.total.toStringAsFixed(2)}";
      await PrinterHelper.bluetooth.printCustom(line, 0, 0);
      count++;
    }
    await PrinterHelper.bluetooth.printNewLine();
    await PrinterHelper.bluetooth.printCustom("*** FIN DEL REPORTE ***", 0, 1);
    await PrinterHelper.bluetooth.printNewLine();
    await PrinterHelper.bluetooth.printNewLine();
    await PrinterHelper.bluetooth.printNewLine();
    await PrinterHelper.bluetooth.printNewLine();
  }
  
  Future<void> _printInventarioReport() async {
    final supplier = _lastReportData['supplier'] as Supplier;
    final entries = _lastReportData['entries'] as List<dynamic>;
    final products = _lastReportData['products'] as Map<int, dynamic>;
    final totalQty = _lastReportData['totalQty'] as int;
    final totalCost = _lastReportData['totalCost'] as double;
    final startDate = _lastReportData['startDate'] as DateTime;
    final endDate = _lastReportData['endDate'] as DateTime;
    final now = DateTime.now();
    
    // Imprimir encabezado
    await PrinterHelper.bluetooth.printCustom("DECOYAMIX", 1, 1);
    await PrinterHelper.bluetooth.printCustom("REPORTE DE INVENTARIO", 1, 1);
    await PrinterHelper.bluetooth.printNewLine();
    
    // Información de proveedor y fechas
    await PrinterHelper.bluetooth.printCustom("Proveedor: ${supplier.name}", 0, 0);
    await PrinterHelper.bluetooth.printCustom("Periodo: ${DateFormat('yyyy-MM-dd').format(startDate)} a ${DateFormat('yyyy-MM-dd').format(endDate)}", 0, 0);
    await PrinterHelper.bluetooth.printCustom("Generado: ${DateFormat('yyyy-MM-dd HH:mm').format(now)}", 0, 0);
    await PrinterHelper.bluetooth.printCustom("--------------------------------", 0, 1);
    
    // Detalle de entradas
    await PrinterHelper.bluetooth.printCustom("DETALLE DE ENTRADAS:", 0, 0);
    for (var entry in entries) {
      final product = products[entry['product_id']];
      final quantity = entry['quantity'] as int;
      final cost = entry['cost'] as double;
      final total = cost * quantity;
      
      String productName = product.name;
      if (productName.length > 16) {
        productName = productName.substring(0, 16) + "...";
      }
      
      await PrinterHelper.bluetooth.printCustom(productName, 0, 0);
      await PrinterHelper.bluetooth.printCustom("Cant: $quantity  Costo: \$${cost.toStringAsFixed(2)}", 0, 0);
      await PrinterHelper.bluetooth.printCustom("Total: \$${total.toStringAsFixed(2)}", 0, 0);
      await PrinterHelper.bluetooth.printCustom("----------------", 0, 1);
    }
    
    // Totales
    await PrinterHelper.bluetooth.printCustom("RESUMEN:", 0, 0);
    await PrinterHelper.bluetooth.printCustom("Cantidad total: $totalQty", 0, 0);
    await PrinterHelper.bluetooth.printCustom("Costo total: \$${totalCost.toStringAsFixed(2)}", 0, 0);
    
    await PrinterHelper.bluetooth.printNewLine();
    await PrinterHelper.bluetooth.printCustom("*** FIN DEL REPORTE ***", 0, 1);
    await PrinterHelper.bluetooth.printNewLine();
    await PrinterHelper.bluetooth.printNewLine();
    await PrinterHelper.bluetooth.printNewLine();
    await PrinterHelper.bluetooth.printNewLine();
  }
  
  Future<void> _printPagosCreditoReport() async {
    final detalles = _lastReportData['detalles'] as List<dynamic>;
    final totalPagado = _lastReportData['totalPagado'] as double;
    final startDate = _lastReportData['startDate'] as DateTime;
    final endDate = _lastReportData['endDate'] as DateTime;
    final now = DateTime.now();
    
    // Imprimir encabezado
    await PrinterHelper.bluetooth.printCustom("DECOYAMIX", 1, 1);
    await PrinterHelper.bluetooth.printCustom("PAGOS A CRÉDITO RECIBIDOS", 1, 1);
    await PrinterHelper.bluetooth.printNewLine();
    
    // Fechas
    await PrinterHelper.bluetooth.printCustom("Periodo: ${DateFormat('yyyy-MM-dd').format(startDate)} a ${DateFormat('yyyy-MM-dd').format(endDate)}", 0, 0);
    await PrinterHelper.bluetooth.printCustom("Generado: ${DateFormat('yyyy-MM-dd HH:mm').format(now)}", 0, 0);
    await PrinterHelper.bluetooth.printCustom("--------------------------------", 0, 1);
    
    // Detalle de pagos
    await PrinterHelper.bluetooth.printCustom("DETALLE DE PAGOS:", 0, 0);
    for (var detalle in detalles) {
      String cliente = detalle['cliente'];
      if (cliente.length > 18) {
        cliente = cliente.substring(0, 18) + "...";
      }
      
      final fecha = DateFormat('yyyy-MM-dd').format(DateTime.parse(detalle['fecha']));
      final monto = detalle['monto'] as double;
      
      await PrinterHelper.bluetooth.printCustom(cliente, 0, 0);
      await PrinterHelper.bluetooth.printCustom("Fecha: $fecha", 0, 0);
      await PrinterHelper.bluetooth.printCustom("Monto: \$${monto.toStringAsFixed(2)}", 0, 0);
      await PrinterHelper.bluetooth.printCustom("----------------", 0, 1);
    }
    
    // Total
    await PrinterHelper.bluetooth.printCustom("TOTAL PAGADO: \$${totalPagado.toStringAsFixed(2)}", 0, 0);
    
    await PrinterHelper.bluetooth.printNewLine();
    await PrinterHelper.bluetooth.printCustom("*** FIN DEL REPORTE ***", 0, 1);
    await PrinterHelper.bluetooth.printNewLine();
    await PrinterHelper.bluetooth.printNewLine();
    await PrinterHelper.bluetooth.printNewLine();
    await PrinterHelper.bluetooth.printNewLine();
  }
  
  Future<void> _printGastosReport() async {
    final gastos = _lastReportData['gastos'] as List<dynamic>;
    final totalGastos = _lastReportData['totalGastos'] as double;
    final startDate = _lastReportData['startDate'] as DateTime;
    final endDate = _lastReportData['endDate'] as DateTime;
    final now = DateTime.now();
    
    // Imprimir encabezado
    await PrinterHelper.bluetooth.printCustom("DECOYAMIX", 1, 1);
    await PrinterHelper.bluetooth.printCustom("HISTORIAL DE GASTOS", 1, 1);
    await PrinterHelper.bluetooth.printNewLine();
    
    // Fechas
    await PrinterHelper.bluetooth.printCustom("Periodo: ${DateFormat('yyyy-MM-dd').format(startDate)} a ${DateFormat('yyyy-MM-dd').format(endDate)}", 0, 0);
    await PrinterHelper.bluetooth.printCustom("Generado: ${DateFormat('yyyy-MM-dd HH:mm').format(now)}", 0, 0);
    await PrinterHelper.bluetooth.printCustom("--------------------------------", 0, 1);
    
    // Detalle de gastos
    await PrinterHelper.bluetooth.printCustom("DETALLE DE GASTOS:", 0, 0);
    for (var gasto in gastos) {
      String concepto = gasto['expense_name'];
      if (concepto.length > 20) {
        concepto = concepto.substring(0, 20) + "...";
      }
      
      final fecha = DateFormat('yyyy-MM-dd').format(DateTime.parse(gasto['date']));
      final monto = gasto['amount'] as double;
      
      await PrinterHelper.bluetooth.printCustom(concepto, 0, 0);
      await PrinterHelper.bluetooth.printCustom("Fecha: $fecha", 0, 0);
      await PrinterHelper.bluetooth.printCustom("Monto: \$${monto.toStringAsFixed(2)}", 0, 0);
      await PrinterHelper.bluetooth.printCustom("----------------", 0, 1);
    }
    
    // Total
    await PrinterHelper.bluetooth.printCustom("TOTAL GASTOS: \$${totalGastos.toStringAsFixed(2)}", 0, 0);
    
    await PrinterHelper.bluetooth.printNewLine();
    await PrinterHelper.bluetooth.printCustom("*** FIN DEL REPORTE ***", 0, 1);
    await PrinterHelper.bluetooth.printNewLine();
    await PrinterHelper.bluetooth.printNewLine();
    await PrinterHelper.bluetooth.printNewLine();
    await PrinterHelper.bluetooth.printNewLine();
  }
  
  Future<void> _printResumenGeneralReport() async {
    final data = _lastReportData['data'] as Map<String, dynamic>;
    final gananciaBruta = _lastReportData['gananciaBruta'] as double;
    final gastos = _lastReportData['gastos'] as double;
    final gananciaNeta = _lastReportData['gananciaNeta'] as double;
    final startDate = _lastReportData['startDate'] as DateTime;
    final endDate = _lastReportData['endDate'] as DateTime;
    final now = DateTime.now();
    
    // Imprimir encabezado
    await PrinterHelper.bluetooth.printCustom("DECOYAMIX", 1, 1);
    await PrinterHelper.bluetooth.printCustom("RESUMEN GENERAL", 1, 1);
    await PrinterHelper.bluetooth.printNewLine();
    
    // Fechas
    await PrinterHelper.bluetooth.printCustom("Periodo: ${DateFormat('yyyy-MM-dd').format(startDate)} a ${DateFormat('yyyy-MM-dd').format(endDate)}", 0, 0);
    await PrinterHelper.bluetooth.printCustom("Generado: ${DateFormat('yyyy-MM-dd HH:mm').format(now)}", 0, 0);
    await PrinterHelper.bluetooth.printCustom("--------------------------------", 0, 1);
    
    // Datos del resumen
    await PrinterHelper.bluetooth.printCustom("Facturas generadas: ${data['facturas']}", 0, 0);
    await PrinterHelper.bluetooth.printCustom("Total Ventas: \$${(data['ventas'] as double).toStringAsFixed(2)}", 0, 0);
    await PrinterHelper.bluetooth.printCustom("Pagos a Crédito: \$${(data['pagos_credito'] as double).toStringAsFixed(2)}", 0, 0);
    await PrinterHelper.bluetooth.printCustom("Descuentos: \$${(data['descuentos'] as double).toStringAsFixed(2)}", 0, 0);
    await PrinterHelper.bluetooth.printCustom("Productos Vendidos: ${data['productos']}", 0, 0);
    await PrinterHelper.bluetooth.printCustom("Ingreso Inventario: \$${(data['inventario'] as double).toStringAsFixed(2)}", 0, 0);
    await PrinterHelper.bluetooth.printCustom("Gastos: \$${gastos.toStringAsFixed(2)}", 0, 0);
    await PrinterHelper.bluetooth.printCustom("Ganancia Estimada: \$${gananciaBruta.toStringAsFixed(2)}", 0, 0);
    await PrinterHelper.bluetooth.printCustom("--------------------------------", 0, 1);
    await PrinterHelper.bluetooth.printCustom("GANANCIA NETA: \$${gananciaNeta.toStringAsFixed(2)}", 1, 0);
    
    await PrinterHelper.bluetooth.printNewLine();
    await PrinterHelper.bluetooth.printCustom("*** FIN DEL REPORTE ***", 0, 1);
    await PrinterHelper.bluetooth.printNewLine();
    await PrinterHelper.bluetooth.printNewLine();
    await PrinterHelper.bluetooth.printNewLine();
    await PrinterHelper.bluetooth.printNewLine();
  }
  
  Future<void> _printFacturasClienteReport() async {
    final cliente = _lastReportData['cliente'] as Client;
    final nombreCliente = _lastReportData['nombreCliente'] as String;
    final facturas = _lastReportData['facturas'] as List<dynamic>;
    final countCredito = _lastReportData['countCredito'] as int;
    final countContado = _lastReportData['countContado'] as int;
    final totalCredito = _lastReportData['totalCredito'] as double;
    final totalContado = _lastReportData['totalContado'] as double;
    final totalPagado = _lastReportData['totalPagado'] as double;
    final totalDeuda = _lastReportData['totalDeuda'] as double;
    final startDate = _lastReportData['startDate'] as DateTime;
    final endDate = _lastReportData['endDate'] as DateTime;
    final now = DateTime.now();
    
    // Imprimir encabezado
    await PrinterHelper.bluetooth.printCustom("DECOYAMIX", 1, 1);
    await PrinterHelper.bluetooth.printCustom("FACTURACIÓN POR CLIENTE", 1, 1);
    await PrinterHelper.bluetooth.printNewLine();
    
    // Información del cliente y fechas
    await PrinterHelper.bluetooth.printCustom("Cliente: $nombreCliente", 0, 0);
    await PrinterHelper.bluetooth.printCustom("Teléfono: ${cliente.phone}", 0, 0);
    await PrinterHelper.bluetooth.printCustom("Periodo: ${DateFormat('yyyy-MM-dd').format(startDate)} a ${DateFormat('yyyy-MM-dd').format(endDate)}", 0, 0);
    await PrinterHelper.bluetooth.printCustom("Generado: ${DateFormat('yyyy-MM-dd HH:mm').format(now)}", 0, 0);
    await PrinterHelper.bluetooth.printCustom("--------------------------------", 0, 1);
    
    // Detalle de facturas (limitado a 15 para no hacer el recibo muy largo)
    await PrinterHelper.bluetooth.printCustom("FACTURAS:", 0, 0);
    int count = 0;
    for (var f in facturas) {
      if (count >= 15) {
        await PrinterHelper.bluetooth.printCustom("... y ${facturas.length - 15} facturas más", 0, 0);
        break;
      }
      
      final total = f['total'] as double;
      final deuda = f['amountDue'] as double;
      final pagado = total - deuda;
      final isCredito = f['isCredit'] == 1;
      final estado = isCredito ? (deuda == 0 ? "PAGADA" : "PENDIENTE") : "";
      final fecha = DateFormat('yyyy-MM-dd').format(DateTime.parse(f['date']));
      
      await PrinterHelper.bluetooth.printCustom("Factura #${f['id']} - $fecha", 0, 0);
      await PrinterHelper.bluetooth.printCustom("Tipo: ${isCredito ? 'Crédito' : 'Contado'} $estado", 0, 0);
      if (isCredito) {
        await PrinterHelper.bluetooth.printCustom("Pagado: \$${pagado.toStringAsFixed(2)}", 0, 0);
      }
      await PrinterHelper.bluetooth.printCustom("Total: \$${total.toStringAsFixed(2)}", 0, 0);
      await PrinterHelper.bluetooth.printCustom("----------------", 0, 1);
      count++;
    }
    
    // Resumen
    await PrinterHelper.bluetooth.printCustom("RESUMEN:", 0, 0);
    await PrinterHelper.bluetooth.printCustom("Facturas a Crédito: $countCredito", 0, 0);
    await PrinterHelper.bluetooth.printCustom("Facturas al Contado: $countContado", 0, 0);
    await PrinterHelper.bluetooth.printCustom("Total a Crédito: \$${totalCredito.toStringAsFixed(2)}", 0, 0);
    await PrinterHelper.bluetooth.printCustom("Total al Contado: \$${totalContado.toStringAsFixed(2)}", 0, 0);
    await PrinterHelper.bluetooth.printCustom("Total Pagado (Crédito): \$${totalPagado.toStringAsFixed(2)}", 0, 0);
    await PrinterHelper.bluetooth.printCustom("Total Adeudado: \$${totalDeuda.toStringAsFixed(2)}", 0, 0);
    
    await PrinterHelper.bluetooth.printNewLine();
    await PrinterHelper.bluetooth.printCustom("*** FIN DEL REPORTE ***", 0, 1);
    await PrinterHelper.bluetooth.printNewLine();
    await PrinterHelper.bluetooth.printNewLine();
    await PrinterHelper.bluetooth.printNewLine();
    await PrinterHelper.bluetooth.printNewLine();
  }
  
  Future<void> _printProductosNegocioReport() async {
    final negocio = _lastReportData['negocio'] as String;
    final data = _lastReportData['data'] as List<dynamic>;
    final totalCantidad = _lastReportData['totalCantidad'] as int;
    final totalDescuento = _lastReportData['totalDescuento'] as double;
    final totalVentas = _lastReportData['totalVentas'] as double;
    final totalGanancia = _lastReportData['totalGanancia'] as double;
    final startDate = _lastReportData['startDate'] as DateTime;
    final endDate = _lastReportData['endDate'] as DateTime;
    final now = DateTime.now();
    
    // Imprimir encabezado
    await PrinterHelper.bluetooth.printCustom("DECOYAMIX", 1, 1);
    await PrinterHelper.bluetooth.printCustom("PRODUCTOS VENDIDOS", 1, 1);
    await PrinterHelper.bluetooth.printCustom("NEGOCIO: $negocio", 1, 1);
    await PrinterHelper.bluetooth.printNewLine();
    
    // Fechas
    await PrinterHelper.bluetooth.printCustom("Periodo: ${DateFormat('yyyy-MM-dd').format(startDate)} a ${DateFormat('yyyy-MM-dd').format(endDate)}", 0, 0);
    await PrinterHelper.bluetooth.printCustom("Generado: ${DateFormat('yyyy-MM-dd HH:mm').format(now)}", 0, 0);
    await PrinterHelper.bluetooth.printCustom("--------------------------------", 0, 1);
    
    // Detalle de productos
    await PrinterHelper.bluetooth.printCustom("PRODUCTOS VENDIDOS:", 0, 0);
    for (var row in data) {
      String producto = row['product_name'];
      if (producto.length > 20) {
        producto = producto.substring(0, 20) + "...";
      }
      
      final cantidad = row['total_quantity'] as int;
      final descuento = row['total_discount'] as double;
      final ventas = row['total_sales'] as double;
      
      await PrinterHelper.bluetooth.printCustom(producto, 0, 0);
      await PrinterHelper.bluetooth.printCustom("Cant: $cantidad  Desc: \$${descuento.toStringAsFixed(2)}", 0, 0);
      await PrinterHelper.bluetooth.printCustom("Total: \$${ventas.toStringAsFixed(2)}", 0, 0);
      await PrinterHelper.bluetooth.printCustom("----------------", 0, 1);
    }
    
    // Totales
    await PrinterHelper.bluetooth.printCustom("RESUMEN:", 0, 0);
    await PrinterHelper.bluetooth.printCustom("Total Productos: $totalCantidad", 0, 0);
    await PrinterHelper.bluetooth.printCustom("Total Descuentos: \$${totalDescuento.toStringAsFixed(2)}", 0, 0);
    await PrinterHelper.bluetooth.printCustom("Total Ventas: \$${totalVentas.toStringAsFixed(2)}", 0, 0);
    await PrinterHelper.bluetooth.printCustom("Total Ganancia: \$${totalGanancia.toStringAsFixed(2)}", 0, 0);
    
    await PrinterHelper.bluetooth.printNewLine();
    await PrinterHelper.bluetooth.printCustom("*** FIN DEL REPORTE ***", 0, 1);
    await PrinterHelper.bluetooth.printNewLine();
    await PrinterHelper.bluetooth.printNewLine();
    await PrinterHelper.bluetooth.printNewLine();
    await PrinterHelper.bluetooth.printNewLine();
  }
  
  Future<void> _printRentablesReport() async {
    final data = _lastReportData['data'] as List<dynamic>;
    final totalArticulos = _lastReportData['totalArticulos'] as int;
    final totalDescuento = _lastReportData['totalDescuento'] as double;
    final totalIngreso = _lastReportData['totalIngreso'] as double;
    final startDate = _lastReportData['startDate'] as DateTime;
    final endDate = _lastReportData['endDate'] as DateTime;
    final now = DateTime.now();
    
    // Imprimir encabezado
    await PrinterHelper.bluetooth.printCustom("DECOYAMIX", 1, 1);
    await PrinterHelper.bluetooth.printCustom("PRODUCTOS RENTABLES", 1, 1);
    await PrinterHelper.bluetooth.printNewLine();
    
    // Fechas
    await PrinterHelper.bluetooth.printCustom("Periodo: ${DateFormat('yyyy-MM-dd').format(startDate)} a ${DateFormat('yyyy-MM-dd').format(endDate)}", 0, 0);
    await PrinterHelper.bluetooth.printCustom("Generado: ${DateFormat('yyyy-MM-dd HH:mm').format(now)}", 0, 0);
    await PrinterHelper.bluetooth.printCustom("--------------------------------", 0, 1);
    
    // Detalle de productos
    await PrinterHelper.bluetooth.printCustom("PRODUCTOS RENTABLES:", 0, 0);
    for (var row in data) {
      String producto = row['product_name'];
      if (producto.length > 20) {
        producto = producto.substring(0, 20) + "...";
      }
      
      final veces = row['times_sold'] as int;
      final descuento = row['total_discount'] as double;
      final ingreso = row['total_income'] as double;
      
      await PrinterHelper.bluetooth.printCustom(producto, 0, 0);
      await PrinterHelper.bluetooth.printCustom("Veces: $veces  Desc: \$${descuento.toStringAsFixed(2)}", 0, 0);
      await PrinterHelper.bluetooth.printCustom("Ingreso: \$${ingreso.toStringAsFixed(2)}", 0, 0);
      await PrinterHelper.bluetooth.printCustom("----------------", 0, 1);
    }
    
    // Totales
    await PrinterHelper.bluetooth.printCustom("RESUMEN:", 0, 0);
    await PrinterHelper.bluetooth.printCustom("Total artículos: $totalArticulos", 0, 0);
    await PrinterHelper.bluetooth.printCustom("Total descuentos: \$${totalDescuento.toStringAsFixed(2)}", 0, 0);
    await PrinterHelper.bluetooth.printCustom("Total ingresos: \$${totalIngreso.toStringAsFixed(2)}", 0, 0);
    
    await PrinterHelper.bluetooth.printNewLine();
    await PrinterHelper.bluetooth.printCustom("*** FIN DEL REPORTE ***", 0, 1);
    await PrinterHelper.bluetooth.printNewLine();
    await PrinterHelper.bluetooth.printNewLine();
    await PrinterHelper.bluetooth.printNewLine();
    await PrinterHelper.bluetooth.printNewLine();
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
            
            if (_lastReportData.isNotEmpty) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _printLastReport,
                icon: const Icon(Icons.print),
                label: const Text('Reimprimir Último Reporte'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: Colors.green,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}