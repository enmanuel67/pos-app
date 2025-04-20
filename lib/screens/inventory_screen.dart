import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import '../models/product.dart';
import 'create_product_screen.dart';

class InventoryScreen extends StatefulWidget {
  final String? initialBarcode;

  const InventoryScreen({Key? key, this.initialBarcode}) : super(key: key);

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _costController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  Product? _selectedProduct;
  String? _notFoundBarcode;
  List<Map<String, dynamic>> _inventoryList = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialBarcode != null) {
      _barcodeController.text = widget.initialBarcode!;
      _searchProductByBarcode();
    }
  }

  void _searchProductByBarcode() async {
    final barcode = _barcodeController.text.trim();
    if (barcode.isEmpty) return;

    final product = await DBHelper.getProductByBarcode(barcode);
    if (product == null) {
      setState(() {
        _selectedProduct = null;
        _notFoundBarcode = barcode;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este producto no existe')),
      );
    } else {
      setState(() {
        _selectedProduct = product;
        _notFoundBarcode = null;
        _costController.text = product.cost.toString();
        _priceController.text = product.price.toString();
      });
    }
  }

  void _addToInventoryList() {
    final qty = int.tryParse(_quantityController.text) ?? 0;
    final cost = double.tryParse(_costController.text) ?? 0.0;
    final price = double.tryParse(_priceController.text) ?? 0.0;

    if (_selectedProduct == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complete los datos correctamente')),
      );
      return;
    }

    setState(() {
      _inventoryList.add({
        'product': _selectedProduct!,
        'quantity': qty,
        'cost': cost,
        'price': price,
      });

      _barcodeController.clear();
      _quantityController.clear();
      _costController.clear();
      _priceController.clear();
      _selectedProduct = null;
    });
  }

  Future<void> _confirmInventory() async {
    for (var item in _inventoryList) {
      final product = item['product'] as Product;
      final quantity = item['quantity'] as int;
      final cost = item['cost'] as double;
      final price = item['price'] as double;

      await DBHelper.updateProductStock(product.id!, quantity, cost);

      // ✅ Actualizar precio si cambió
      if (price != product.price) {
        final updatedProduct = product.copyWith(price: price);
        await DBHelper.updateProduct(updatedProduct);
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Inventario actualizado')),
    );

    setState(() {
      _inventoryList.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ingreso a Inventario')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _barcodeController,
              decoration: InputDecoration(
                labelText: 'Código de barra',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _searchProductByBarcode,
                ),
              ),
              onSubmitted: (_) => _searchProductByBarcode(),
            ),
            const SizedBox(height: 10),

            if (_selectedProduct != null) ...[
              Text('Nombre: ${_selectedProduct!.name}'),
              Text('Descripción: ${_selectedProduct!.description}'),
              Text('Precio actual: \$${_selectedProduct!.price}'),
              Text('Cantidad actual: ${_selectedProduct!.quantity}'),
              const SizedBox(height: 10),

              TextField(
                controller: _costController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Costo unitario'),
              ),
              TextField(
                controller: _priceController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Precio de venta'),
              ),
              TextField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Cantidad a agregar'),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _addToInventoryList,
                child: const Text('Agregar a la lista'),
              ),
              const Divider(),
            ],

            if (_notFoundBarcode != null) ...[
              const SizedBox(height: 10),
              Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add_box_outlined),
                  label: const Text('Crear nuevo producto'),
                  onPressed: () async {
  final created = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => CreateProductScreen(initialBarcode: _notFoundBarcode!),
    ),
  );

  if (created == true) {
    // Buscar de nuevo el producto creado por el código de barra
    _searchProductByBarcode();
  }
},

                ),
              ),
              const SizedBox(height: 10),
              const Divider(),
            ],

            const Text('Productos por agregar:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: _inventoryList.length,
                itemBuilder: (_, index) {
                  final item = _inventoryList[index];
                  final product = item['product'] as Product;
                  final quantity = item['quantity'];
                  final cost = item['cost'];
                  final price = item['price'];
                  final total = (cost * quantity).toStringAsFixed(2);

                  return ListTile(
                    title: Text(product.name),
                    subtitle: Text(
                      'Cantidad: $quantity | Costo: \$${cost.toStringAsFixed(2)} | Precio: \$${price.toStringAsFixed(2)}',
                    ),
                    trailing: Text('Total: \$${total}'),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            if (_inventoryList.isNotEmpty)
              Center(
                child: ElevatedButton.icon(
                  onPressed: _confirmInventory,
                  icon: const Icon(Icons.inventory),
                  label: const Text('Confirmar ingreso a inventario'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
