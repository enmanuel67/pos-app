import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import 'package:pos_app/models/product.dart';
import '../models/client.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Product> _lowStockProducts = [];
  List<Map<String, dynamic>> _overdueInvoices = [];
  String _selectedFilter = 'Todo';

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final products = await DBHelper.getProducts();
    final allSales = await DBHelper.getAllSales();

    List<Map<String, dynamic>> overdue = [];
    final today = DateTime.now();

    for (var sale in allSales) {
      if (sale.isCredit && !sale.isPaid) {
        final saleDate = DateTime.parse(sale.date);
        final daysOverdue = today.difference(saleDate).inDays;

        if (daysOverdue >= 15) {
          final client = await DBHelper.getClientByPhone(sale.clientPhone!);
          if (client != null) {
            overdue.add({
              'client': client,
              'amount': sale.amountDue,
              'days': daysOverdue,
            });
          }
        }
      }
    }

    setState(() {
      _lowStockProducts =
          products
              .where((p) => p.quantity <= 5 && (p.isRentable != true))
              .toList(); // ✅ Aquí se filtran los rentables
      _overdueInvoices = overdue;
    });
  }

  @override
  Widget build(BuildContext context) {
    final showStock =
        _selectedFilter == 'Todo' || _selectedFilter == 'Bajo stock';
    final showOverdue =
        _selectedFilter == 'Todo' || _selectedFilter == 'Facturas vencidas';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          DropdownButton<String>(
            value: _selectedFilter,
            underline: Container(),
            onChanged: (val) {
              if (val != null) {
                setState(() => _selectedFilter = val);
              }
            },
            items: const [
              DropdownMenuItem(value: 'Todo', child: Text('Todo')),
              DropdownMenuItem(value: 'Bajo stock', child: Text('Bajo stock')),
              DropdownMenuItem(
                value: 'Facturas vencidas',
                child: Text('Facturas vencidas'),
              ),
            ],
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: ListView(
        children: [
          if (showStock && _lowStockProducts.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                '🛒 Productos con inventario bajo:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ..._lowStockProducts.map(
              (p) => ListTile(
                leading: const Icon(Icons.warning, color: Colors.red),
                title: Text(p.name),
                subtitle: Text('Cantidad actual: ${p.quantity}'),
              ),
            ),
          ],
          if (showOverdue && _overdueInvoices.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                '💳 Facturas vencidas:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ..._overdueInvoices.map((e) {
              final Client c = e['client'];
              final amount = e['amount'] as double;
              final days = e['days'] as int;

              return ListTile(
                leading: const Icon(Icons.schedule, color: Colors.orange),
                title: Text('${c.name} ${c.lastName}'),
                subtitle: Text(
                  'Debe \$${amount.toStringAsFixed(2)} desde hace $days días',
                ),
              );
            }),
          ],
          if (!showStock && !showOverdue)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('No hay notificaciones disponibles.'),
              ),
            ),
        ],
      ),
    );
  }
}
