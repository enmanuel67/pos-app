import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/db_helper.dart';
import '../models/sale.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  List<Sale> _filteredSales = [];

  double creditTotal = 0;
  double cashTotal = 0;

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

    final sales = await DBHelper.getAllSales();
    final filtered = sales.where((s) {
      final saleDate = DateTime.parse(s.date);
      return saleDate.isAfter(_startDate!.subtract(Duration(days: 1))) &&
          saleDate.isBefore(_endDate!.add(Duration(days: 1)));
    }).toList();

    double credit = 0;
    double cash = 0;

    for (var s in filtered) {
      if (s.isCredit) {
        credit += s.total;
      } else {
        cash += s.total;
      }
    }

    setState(() {
      _filteredSales = filtered;
      creditTotal = credit;
      cashTotal = cash;
    });

    _showPreview();
  }

void _showPreview() {
  final total = creditTotal + cashTotal;
  final now = DateTime.now();
  final format = DateFormat('yyyy-MM-dd HH:mm:ss');

  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text('Reporte de Facturación'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('•  Rango del Reporte: ${DateFormat('yyyy-MM-dd').format(_startDate!)} a ${DateFormat('yyyy-MM-dd').format(_endDate!)}'),
            Text('•  Fecha de Generación: ${format.format(now)}'),
            const SizedBox(height: 20),
            const Divider(),
            const Text('🧾 Facturas Individuales:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ..._filteredSales.map((sale) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Factura #${sale.id}'),
              subtitle: Text('Fecha: ${DateFormat('yyyy-MM-dd').format(DateTime.parse(sale.date))}'),
              trailing: Text('\$${sale.total.toStringAsFixed(2)}'),
            )),
            Row(children: const [
              Icon(Icons.receipt_long),
              SizedBox(width: 8),
              Text("Cantidad de Facturas:", style: TextStyle(fontWeight: FontWeight.bold)),
            ]),
            Text("${_filteredSales.length}"),
            const SizedBox(height: 8),
            Row(children: const [
              Icon(Icons.credit_card, color: Colors.amber),
              SizedBox(width: 8),
              Text("Total en Ventas a Crédito:", style: TextStyle(fontWeight: FontWeight.bold)),
            ]),
            Text("\$${creditTotal.toStringAsFixed(2)}"),
            const SizedBox(height: 8),
            Row(children: const [
              Icon(Icons.payments, color: Colors.green),
              SizedBox(width: 8),
              Text("Total en Ventas al Contado:", style: TextStyle(fontWeight: FontWeight.bold)),
            ]),
            Text("\$${cashTotal.toStringAsFixed(2)}"),
            const SizedBox(height: 8),
            Row(children: const [
              Icon(Icons.bar_chart, color: Colors.red),
              SizedBox(width: 8),
              Text("Total General de Ventas:", style: TextStyle(fontWeight: FontWeight.bold)),
            ]),
            Text("\$${total.toStringAsFixed(2)}"),
            const SizedBox(height: 24),
            const Divider(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cerrar'),
        )
      ],
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd');

    return Scaffold(
      appBar: AppBar(title: Text('Reporte de Facturación')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _selectDate(context, true),
                    child: Text(
                        _startDate == null ? 'Desde' : dateFormat.format(_startDate!)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _selectDate(context, false),
                    child: Text(
                        _endDate == null ? 'Hasta' : dateFormat.format(_endDate!)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _generateReport,
              icon: Icon(Icons.print),
              label: Text('Generar Reporte'),
              style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 48)),
            ),
          ],
        ),
      ),
    );
  }
}
