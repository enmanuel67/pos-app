import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import '../models/product.dart';
import '../models/supplier.dart';

class EditProductScreen extends StatefulWidget {
  final Product product;

  EditProductScreen({required this.product});

  @override
  _EditProductScreenState createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController nameController;
  late TextEditingController barcodeController;
  late TextEditingController descriptionController;
  late TextEditingController priceController;
  late TextEditingController quantityController;
  List<Supplier> suppliers = [];
  int? selectedSupplierId;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.product.name);
    barcodeController = TextEditingController(text: widget.product.barcode);
    descriptionController = TextEditingController(text: widget.product.description);
    priceController = TextEditingController(text: widget.product.price.toString());
    quantityController = TextEditingController(text: widget.product.quantity.toString());
    selectedSupplierId = widget.product.supplierId;
    _loadSuppliers();
  }

  void _loadSuppliers() async {
    final data = await DBHelper.getSuppliers();
    setState(() {
      suppliers = data;
    });
  }

  void _saveChanges() async {
    if (_formKey.currentState!.validate()) {
      final updatedProduct = Product(
        id: widget.product.id,
        name: nameController.text.trim(),
        barcode: barcodeController.text.trim(),
        description: descriptionController.text.trim(),
        price: double.tryParse(priceController.text) ?? 0,
        quantity: int.tryParse(quantityController.text) ?? 0,
        supplierId: selectedSupplierId,
      );

      await DBHelper.updateProduct(updatedProduct);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Producto actualizado')));
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Editar Producto')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: nameController,
                decoration: InputDecoration(labelText: 'Nombre'),
                validator: (value) => value!.isEmpty ? 'Campo requerido' : null,
              ),
              TextFormField(
                controller: barcodeController,
                decoration: InputDecoration(labelText: 'Código de Barra'),
              ),
              TextFormField(
                controller: descriptionController,
                decoration: InputDecoration(labelText: 'Descripción'),
              ),
              TextFormField(
                controller: priceController,
                decoration: InputDecoration(labelText: 'Precio'),
                keyboardType: TextInputType.number,
              ),
              TextFormField(
                controller: quantityController,
                decoration: InputDecoration(labelText: 'Cantidad'),
                keyboardType: TextInputType.number,
              ),
              DropdownButtonFormField<int>(
                value: selectedSupplierId,
                items: suppliers.map((supplier) {
                  return DropdownMenuItem<int>(
                    value: supplier.id,
                    child: Text(supplier.name),
                  );
                }).toList(),
                onChanged: (value) => setState(() => selectedSupplierId = value),
                decoration: InputDecoration(labelText: 'Proveedor'),
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveChanges,
                child: Text('Guardar Cambios'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
