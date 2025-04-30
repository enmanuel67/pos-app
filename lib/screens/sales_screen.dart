import 'package:flutter/material.dart';
import 'package:pos_app/models/product.dart';
import '../db/db_helper.dart';
import 'sale_summary_screen.dart';

class SalesScreen extends StatefulWidget {
  final String? clientPhone;

  const SalesScreen({Key? key, this.clientPhone}) : super(key: key);

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  final Map<Product, int> _cart = {};
  final TextEditingController _searchController = TextEditingController();
  double _total = 0.0;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _searchController.addListener(_filterProducts);
  }

  void _loadProducts() async {
    final products = await DBHelper.getProducts();
    setState(() {
      _products = products;
      _filteredProducts = products;
    });
  }

  void _filterProducts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredProducts =
          _products.where((p) => p.name.toLowerCase().contains(query)).toList();
    });
  }

  void _addToCart(Product product) {
    setState(() {
      _cart[product] = (_cart[product] ?? 0) + 1;
      _calculateTotal();
    });
  }

  void _removeFromCart(Product product) {
    setState(() {
      if (_cart.containsKey(product) && _cart[product]! > 1) {
        _cart[product] = _cart[product]! - 1;
      } else {
        _cart.remove(product);
      }
      _calculateTotal();
    });
  }

  void _calculateTotal() {
    _total = 0.0;
    _cart.forEach((product, qty) {
      _total += product.price * qty;
    });
  }

  void _selectPaymentMethod() {
    if (_cart.isEmpty) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Tipo de venta'),
        content: const Text('¿Cómo desea registrar esta venta?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _goToSummary(isCredit: false);
            },
            child: const Text('Contado'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _goToSummary(isCredit: true);
            },
            child: const Text('Crédito'),
          ),
        ],
      ),
    );
  }

  void _goToSummary({required bool isCredit}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SaleSummaryScreen(
          selectedProducts: Map<Product, int>.from(_cart),
          clientPhone: widget.clientPhone,
          isCredit: isCredit,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Seleccionar productos')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Buscar producto...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _filteredProducts.length,
              itemBuilder: (context, index) {
                final product = _filteredProducts[index];
                final qty = _cart[product] ?? 0;
                return ListTile(
                  title: Text(product.name),
                  subtitle: Text('\$${product.price.toStringAsFixed(2)}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: () => _removeFromCart(product)),
                      Text(qty.toString()),
                      IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () => _addToCart(product)),
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
                Text('Total: \$${_total.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 18)),
                ElevatedButton(
                  onPressed: _cart.isEmpty ? null : _selectPaymentMethod,
                  child: const Text('Confirmar venta'),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
