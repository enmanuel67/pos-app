import 'package:flutter/material.dart';
import '../models/sale.dart';
import '../models/product.dart';
import '../models/sale_item.dart';
import '../models/client.dart';
import '../db/db_helper.dart';

class SaleDetailScreen extends StatefulWidget {
  final Sale sale;

  const SaleDetailScreen({super.key, required this.sale});

  @override
  State<SaleDetailScreen> createState() => _SaleDetailScreenState();
}

class _SaleDetailScreenState extends State<SaleDetailScreen> {
  List<SaleItem> _items = [];
  Map<int, Product> _productMap = {};
  Client? _client;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    final items = await DBHelper.getSaleItems(widget.sale.id!);
    final allProducts = await DBHelper.getProducts();
    final productMap = {for (var p in allProducts) p.id!: p};

    Client? client;
    if (widget.sale.clientPhone != null) {
      client = await DBHelper.getClientByPhone(widget.sale.clientPhone!);
    }

    setState(() {
      _items = items;
      _productMap = productMap;
      _client = client;
    });
  }

  void _showReceiptPreview() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Factura #${widget.sale.id}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_client != null)
              Text('Cliente: ${_client!.name} ${_client!.lastName}'),
            Text('Fecha: ${widget.sale.date.split("T").first}'),
            Text('Tipo de venta: ${widget.sale.isCredit ? "Crédito" : "Contado"}'),
            SizedBox(height: 8),
            Text('Productos:', style: TextStyle(fontWeight: FontWeight.bold)),
            ..._items.map((item) {
              final product = _productMap[item.productId];
              return Text(
                  '${product?.name ?? "Producto"} x${item.quantity} - \$${item.subtotal.toStringAsFixed(2)}');
            }),
            Divider(),
            Text('Total: \$${widget.sale.total.toStringAsFixed(2)}',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Factura #${widget.sale.id}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_client != null) ...[
              Text('Cliente: ${_client!.name} ${_client!.lastName}'),
              Text('Teléfono: ${_client!.phone}'),
            ],
            Text('Fecha: ${widget.sale.date.split("T").first}'),
            Text('Tipo de venta: ${widget.sale.isCredit ? "Crédito" : "Contado"}'),
            const SizedBox(height: 16),
            const Text('Productos:', style: TextStyle(fontWeight: FontWeight.bold)),
            Expanded(
              child: ListView.separated(
                itemCount: _items.length,
                separatorBuilder: (_, __) => Divider(),
                itemBuilder: (_, index) {
                  final item = _items[index];
                  final product = _productMap[item.productId];
                  return ListTile(
                    title: Text(product?.name ?? 'Producto'),
                    subtitle: Text('Cantidad: ${item.quantity}'),
                    trailing: Text('\$${item.subtotal.toStringAsFixed(2)}'),
                  );
                },
              ),
            ),
            Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('Total: \$${widget.sale.total.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Center(
              child: ElevatedButton.icon(
                onPressed: _showReceiptPreview,
                icon: Icon(Icons.print),
                label: Text('Reimprimir factura'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
