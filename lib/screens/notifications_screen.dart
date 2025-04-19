import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import '../models/product.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Product> _lowStockProducts = [];

  @override
  void initState() {
    super.initState();
    _loadLowStockProducts();
  }

  Future<void> _loadLowStockProducts() async {
    final products = await DBHelper.getProducts();
    setState(() {
      _lowStockProducts = products.where((p) => p.quantity <= 5).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones')),
      body: _lowStockProducts.isEmpty
          ? const Center(child: Text('No hay productos con inventario bajo.'))
          : ListView.builder(
              itemCount: _lowStockProducts.length,
              itemBuilder: (context, index) {
                final product = _lowStockProducts[index];
                return ListTile(
                  leading: const Icon(Icons.warning, color: Colors.red),
                  title: Text(product.name),
                  subtitle: Text('Cantidad: ${product.quantity}'),
                );
              },
            ),
    );
  }
}
