import 'package:flutter/material.dart';
import 'package:pos_app/screens/inventory_screen.dart';
import 'package:pos_app/screens/billing_screen.dart';
import 'package:pos_app/screens/clients_screen.dart';
import 'package:pos_app/screens/report_screen.dart';
import 'package:pos_app/screens/sales_history_screen.dart';
import 'package:pos_app/screens/suppliers_screen.dart';
import 'products_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<_DashboardItem> items = [
      _DashboardItem('Facturación', Icons.point_of_sale, () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => BillingScreen()));
      }),
      _DashboardItem('Productos', Icons.inventory_2, () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ProductsScreen()));
      }),
      _DashboardItem('Clientes', Icons.people, () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ClientsScreen()));
      }),
      _DashboardItem('Proveedores', Icons.local_shipping, () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => SuppliersScreen()));
      }),
      _DashboardItem('Historial', Icons.history, () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => SalesHistoryScreen()));
      }),
      _DashboardItem('Reportes', Icons.receipt, () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ReportScreen()));
      }),
            _DashboardItem('Inventario', Icons.add_shopping_cart, () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => InventoryScreen()));
      }),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('POS Dashboard'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: GridView.builder(
          itemCount: items.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            return GestureDetector(
              onTap: item.onTap,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.blue.shade600,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 5,
                      offset: Offset(2, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(item.icon, size: 48, color: Colors.white),
                    const SizedBox(height: 12),
                    Text(
                      item.label,
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DashboardItem {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  _DashboardItem(this.label, this.icon, this.onTap);
}
