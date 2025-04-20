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

    if (_reportType == 'facturacion') {
      final sales = await DBHelper.getAllSales();
      final filtered = sales.where((s) {
        final saleDate = DateTime.parse(s.date);
        return saleDate.isAfter(_startDate!.subtract(const Duration(days: 1))) &&
            saleDate.isBefore(_endDate!.add(const Duration(days: 1)));
      }).toList();

      double credit = 0;
      double cash = 0;
      double profit = 0;

      for (var s in filtered) {
        if (s.isCredit) {
          credit += s.total;
        } else {
          cash += s.total;
        }

        final items = await DBHelper.getSaleItems(s.id!);
        for (var item in items) {
          final product = await DBHelper.getProductById(item.productId);
          final cost = product?.cost ?? 0;
          final gain = ((item.subtotal / item.quantity) - item.discount - cost) * item.quantity;
          profit += gain;
        }
      }

      setState(() {
        _filteredSales = filtered;
        creditTotal = credit;
        cashTotal = cash;
        profitTotal = profit;
      });

      _showSalesPreview();
    } else {
      if (_selectedSupplier == null) return;

      final entries = await DBHelper.getInventoryEntriesBySupplierAndDate(
        _selectedSupplier!.id!,
        _startDate!,
        _endDate!,
      );

      final products = await DBHelper.getProducts();
      final productMap = {for (var p in products) p.id!: p};

      final totalQty = entries.fold<int>(0, (sum, e) => sum + (e['quantity'] as int));
      final totalCost = entries.fold<double>(
        0.0,
        (sum, e) => sum + ((e['cost'] as num) * (e['quantity'] as int)),
      );

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Reporte de Inventario'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Proveedor: ${_selectedSupplier!.name}'),
                Text('Rango: ${DateFormat('yyyy-MM-dd').format(_startDate!)} - ${DateFormat('yyyy-MM-dd').format(_endDate!)}'),
                Text('Generado: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}'),
                const Divider(),
                ...entries.map((e) {
                  final product = productMap[e['product_id']]!;
                  final quantity = e['quantity'];
                  final cost = e['cost'];
                  final total = (cost * quantity).toStringAsFixed(2);

                  return ListTile(
                    title: Text(product.name),
                    subtitle: Text('Cantidad: $quantity  |  Costo: \$${cost.toStringAsFixed(2)}'),
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
  }

  void _showSalesPreview() {
    final total = creditTotal + cashTotal;
    final now = DateTime.now();
    final format = DateFormat('yyyy-MM-dd HH:mm:ss');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reporte de Facturación'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Rango del Reporte: ${DateFormat('yyyy-MM-dd').format(_startDate!)} a ${DateFormat('yyyy-MM-dd').format(_endDate!)}'),
              Text('Fecha de Generación: ${format.format(now)}'),
              const Divider(),
              const Text('🧾 Facturas:', style: TextStyle(fontWeight: FontWeight.bold)),
              ..._filteredSales.map((sale) => ListTile(
                title: Text('Factura #${sale.id}'),
                subtitle: Text('Fecha: ${DateFormat('yyyy-MM-dd').format(DateTime.parse(sale.date))}'),
                trailing: Text('\$${sale.total.toStringAsFixed(2)}'),
              )),
              const Divider(),
              Text('Cantidad de Facturas: ${_filteredSales.length}'),
              Text('Total en Ventas a Crédito: \$${creditTotal.toStringAsFixed(2)}'),
              Text('Total en Ventas al Contado: \$${cashTotal.toStringAsFixed(2)}'),
              Text('Total General de Ventas: \$${total.toStringAsFixed(2)}'),
              Text('Ganancia Total: \$${profitTotal.toStringAsFixed(2)}'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
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
                DropdownMenuItem(value: 'facturacion', child: Text('Facturación')),
                DropdownMenuItem(value: 'inventario', child: Text('Inventario por proveedor')),
              ],
              onChanged: (val) => setState(() => _reportType = val!),
            ),
            const SizedBox(height: 16),
            if (_reportType == 'inventario') ...[
              DropdownButtonFormField<Supplier>(
                decoration: const InputDecoration(labelText: 'Proveedor'),
                value: _selectedSupplier,
                items: _suppliers
                    .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
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
                    child: Text(_startDate == null ? 'Desde' : dateFormat.format(_startDate!)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _selectDate(context, false),
                    child: Text(_endDate == null ? 'Hasta' : dateFormat.format(_endDate!)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _generateReport,
              icon: const Icon(Icons.analytics),
              label: const Text('Generar Reporte'),
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
          ],
        ),
      ),
    );
  }
}
