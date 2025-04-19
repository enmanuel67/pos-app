import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../models/sale_item.dart';
import '../models/client.dart';
import '../db/db_helper.dart';

class SaleSummaryScreen extends StatefulWidget {
  final Map<Product, int> selectedProducts;
  final String? clientPhone;
  final bool isCredit;

  const SaleSummaryScreen({
    Key? key,
    required this.selectedProducts,
    this.clientPhone,
    required this.isCredit,
  }) : super(key: key);

  @override
  State<SaleSummaryScreen> createState() => _SaleSummaryScreenState();
}

class _SaleSummaryScreenState extends State<SaleSummaryScreen> {
  late Map<Product, int> _products;
  double _total = 0.0;
  Client? _client;

  @override
  void initState() {
    super.initState();
    _products = Map.from(widget.selectedProducts);
    _calculateTotal();
    _loadClient();
  }

  void _calculateTotal() {
    _total = _products.entries
        .map((e) => e.key.price * e.value)
        .fold(0.0, (a, b) => a + b);
    setState(() {});
  }

  void _changeQuantity(Product product, int delta) {
    setState(() {
      int newQty = (_products[product] ?? 0) + delta;
      if (newQty <= 0) {
        _products.remove(product);
      } else {
        _products[product] = newQty;
      }
      _calculateTotal();
    });
  }

  Future<void> _loadClient() async {
    if (widget.clientPhone != null) {
      final result = await DBHelper.getClientByPhone(widget.clientPhone!);
      setState(() {
        _client = result;
      });
    }
  }

  Future<void> _confirmSale() async {
  if (widget.isCredit && _client == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('No se puede hacer venta a crédito sin cliente')),
    );
    return;
  }

  if (widget.isCredit && _client!.creditLimit < _total) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('El total excede el límite de crédito del cliente')),
    );
    return;
  }

  final now = DateTime.now().toIso8601String();
  final sale = Sale(
    date: now,
    total: _total,
    clientPhone: widget.clientPhone,
    isCredit: widget.isCredit,
  );
  final saleId = await DBHelper.insertSale(sale);

  final items = _products.entries.map((entry) {
    return SaleItem(
      saleId: saleId,
      productId: entry.key.id!,
      quantity: entry.value,
      subtotal: entry.key.price * entry.value,
    );
  }).toList();

  await DBHelper.insertSaleItems(items);

  // ✅ Reducir inventario por cada producto vendido
  for (var entry in _products.entries) {
    await DBHelper().reduceProductStock(entry.key.id!, entry.value);
  }

  if (widget.isCredit && _client != null) {
    await DBHelper.updateClientCredit(
      _client!.phone,
      _client!.credit + _total,
      _client!.creditAvailable - _total,
    );
  }

  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(widget.isCredit ? 'Factura (Crédito)' : 'Factura (Contado)'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_client != null) ...[
              Text('Cliente: ${_client!.name} ${_client!.lastName}'),
              Text('Teléfono: ${_client!.phone}'),
              SizedBox(height: 10),
            ],
            Text('Fecha: ${DateTime.now()}'),
            Divider(),
            ..._products.entries.map((entry) {
              final product = entry.key;
              final qty = entry.value;
              final subtotal = (product.price * qty).toStringAsFixed(2);
              return Text('${product.name} x$qty - \$${subtotal}');
            }).toList(),
            Divider(),
            Text('Total: \$${_total.toStringAsFixed(2)}',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            Navigator.popUntil(context, ModalRoute.withName('/'));
          },
          child: Text('Aceptar'),
        ),
      ],
    ),
  );
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Resumen de Venta')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _products.length,
              itemBuilder: (_, index) {
                final product = _products.keys.elementAt(index);
                final quantity = _products[product]!;
                final subtotal = product.price * quantity;
                return ListTile(
                  title: Text(product.name),
                  subtitle: Text('Cantidad: $quantity - Subtotal: \$${subtotal.toStringAsFixed(2)}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.remove),
                        onPressed: () => _changeQuantity(product, -1),
                      ),
                      IconButton(
                        icon: Icon(Icons.add),
                        onPressed: () => _changeQuantity(product, 1),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total: \$${_total.toStringAsFixed(2)}', style: TextStyle(fontSize: 18)),
                ElevatedButton(
                  onPressed: _products.isEmpty ? null : _confirmSale,
                  child: Text('Confirmar Venta'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
