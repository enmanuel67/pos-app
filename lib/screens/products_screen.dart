import 'package:flutter/material.dart';
import 'package:pos_app/screens/edit_product_screen.dart';
import '../db/db_helper.dart';
import 'package:pos_app/models/product.dart';
import 'create_product_screen.dart';

enum ProductSort {
  newest,
  oldest,
  nameAZ,
  nameZA,
}

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({Key? key}) : super(key: key);

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  final TextEditingController _searchController = TextEditingController();

  ProductSort _sort = ProductSort.newest; // ✅ default: más nuevo

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _searchController.addListener(_applyFilters);
  }

  Future<void> _loadProducts() async {
    final products = await DBHelper.getProducts();
    setState(() {
      _products = products;
    });
    _applyFilters();
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();

    // ✅ 1) filtrar por búsqueda (nombre + barcode opcional)
    List<Product> list = _products.where((product) {
      final name = product.name.toLowerCase();
      final barcode = (product.barcode ?? '').toLowerCase();
      return name.contains(query) || barcode.contains(query);
    }).toList();

    // ✅ 2) ordenar según filtro
    switch (_sort) {
      case ProductSort.newest:
        // createdAt ISO => se puede comparar como string
        list.sort((a, b) => (b.createdAt ?? '').compareTo(a.createdAt ?? ''));
        break;

      case ProductSort.oldest:
        list.sort((a, b) => (a.createdAt ?? '').compareTo(b.createdAt ?? ''));
        break;

      case ProductSort.nameAZ:
        list.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        break;

      case ProductSort.nameZA:
        list.sort(
          (a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()),
        );
        break;
    }

    setState(() {
      _filteredProducts = list;
    });
  }

  void _deleteProduct(int id) async {
    await DBHelper.deleteProduct(id);
    await _loadProducts();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Producto eliminado')),
    );
  }

  @override
  void dispose() {
    _searchController.removeListener(_applyFilters);
    _searchController.dispose();
    super.dispose();
  }

  String _sortLabel(ProductSort s) {
    switch (s) {
      case ProductSort.newest:
        return 'Más nuevo';
      case ProductSort.oldest:
        return 'Más viejo';
      case ProductSort.nameAZ:
        return 'A - Z';
      case ProductSort.nameZA:
        return 'Z - A';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Productos')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                // 🔎 Buscar
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Buscar producto',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // ✅ Orden / filtro
                DropdownButton<ProductSort>(
                  value: _sort,
                  onChanged: (val) {
                    if (val == null) return;
                    setState(() => _sort = val);
                    _applyFilters();
                  },
                  items: ProductSort.values.map((s) {
                    return DropdownMenuItem(
                      value: s,
                      child: Text(_sortLabel(s)),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView.builder(
              itemCount: _filteredProducts.length,
              itemBuilder: (context, index) {
                final product = _filteredProducts[index];

                return ListTile(
                  title: Row(
                    children: [
                      Expanded(child: Text(product.name)),
                      if (product.isRentable == true)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blueGrey,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'RENTADO',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Text(
                    'Precio: \$${product.price.toStringAsFixed(2)} | '
                    'Cantidad: ${product.isRentable == true ? "∞" : product.quantity}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  EditProductScreen(product: product),
                            ),
                          );
                          await _loadProducts();
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _deleteProduct(product.id!),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => CreateProductScreen()),
          );
          await _loadProducts();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
