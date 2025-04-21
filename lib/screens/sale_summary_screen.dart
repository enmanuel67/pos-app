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
  Map<int, double> _discounts = {};
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
    _total = 0.0;
    _products.forEach((product, qty) {
      final discount = _discounts[product.id] ?? 0.0;
      _total += (product.price - discount) * qty;
    });
    setState(() {});
  }

  void _changeQuantity(Product product, int delta) {
    final currentQty = _products[product] ?? 0;
    final newQty = currentQty + delta;

    if (delta > 0 && newQty > product.quantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Stock insuficiente para ${product.name}')),
      );
      return;
    }

    setState(() {
      if (newQty <= 0) {
        _products.remove(product);
      } else {
        _products[product] = newQty;
      }
      _calculateTotal();
    });
  }

  void _editDiscount(Product product) {
    final controller = TextEditingController(
      text: (_discounts[product.id] ?? 0.0).toString(),
    );
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text('Descuento para ${product.name}'),
            content: TextField(
              controller: controller,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Descuento por unidad'),
            ),
            actions: [
              TextButton(
                child: Text('Cancelar'),
                onPressed: () => Navigator.pop(context),
              ),
              TextButton(
                child: Text('Aplicar'),
                onPressed: () {
                  final value = double.tryParse(controller.text.trim()) ?? 0.0;
                  Navigator.pop(context);
                  setState(() {
                    _discounts[product.id!] = value;
                    _calculateTotal();
                  });
                },
              ),
            ],
          ),
    );
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
    final insufficient = _products.entries.where(
      (entry) => entry.key.quantity < entry.value,
    );
    if (insufficient.isNotEmpty) {
      final names = insufficient.map((e) => e.key.name).join(', ');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Stock insuficiente para: $names')),
      );
      return;
    }

    if (widget.isCredit && widget.clientPhone != null) {
      final liveClient = await DBHelper.getClientByPhone(widget.clientPhone!);

      if (liveClient == null || !liveClient.hasCredit) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Este cliente no tiene crédito habilitado.')),
        );
        return;
      }

      if (liveClient.creditAvailable < _total) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('El total excede el crédito disponible del cliente'),
          ),
        );
        return;
      }

      _client = liveClient;
    }

    final now = DateTime.now().toIso8601String();
    final sale = Sale(
      date: now,
      total: _total,
      amountDue: _total, // 👈 nuevo campo requerido
      clientPhone: widget.clientPhone,
      isCredit: widget.isCredit,
    );
    final saleId = await DBHelper.insertSale(sale);

    final items =
        _products.entries.map((entry) {
          final product = entry.key;
          final qty = entry.value;
          final discount = _discounts[product.id] ?? 0.0;
          final subtotal = (product.price - discount) * qty;

          return SaleItem(
            saleId: saleId,
            productId: product.id!,
            quantity: qty,
            subtotal: subtotal,
            discount: discount,
          );
        }).toList();

    await DBHelper.insertSaleItems(items);

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

    final totalDiscount = _products.entries.fold(0.0, (sum, entry) {
      final discount = _discounts[entry.key.id] ?? 0.0;
      return sum + (discount * entry.value);
    });

    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text(
              widget.isCredit ? 'Factura (Crédito)' : 'Factura (Contado)',
            ),
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
                    final discount = _discounts[entry.key.id] ?? 0.0;
                    final subtotal = ((entry.key.price - discount) *
                            entry.value)
                        .toStringAsFixed(2);
                    return Text(
                      '${entry.key.name} x${entry.value} - \$${subtotal} (${discount > 0 ? "Descuento \$${discount.toStringAsFixed(2)} c/u" : "Sin descuento"})',
                    );
                  }),
                  Divider(),
                  Text(
                    '💸 Descuento total aplicado: \$${totalDiscount.toStringAsFixed(2)}',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Total: \$${_total.toStringAsFixed(2)}',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
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
          if (_client != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cliente: ${_client!.name} ${_client!.lastName}'),
                  if (_client!.hasCredit)
                    Text(
                      'Crédito disponible: \$${_client!.creditAvailable.toStringAsFixed(2)}',
                    ),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: _products.length,
              itemBuilder: (_, index) {
                final product = _products.keys.elementAt(index);
                final quantity = _products[product]!;
                final discount = _discounts[product.id] ?? 0.0;
                final subtotal = (product.price - discount) * quantity;

                return ListTile(
                  title: Text(product.name),
                  subtitle: Text(
                    'Cantidad: $quantity - Subtotal: \$${subtotal.toStringAsFixed(2)}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.discount),
                        onPressed: () => _editDiscount(product),
                      ),
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
                Text(
                  'Total: \$${_total.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 18),
                ),
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
