import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import '../models/product.dart';
import '../models/supplier.dart';

class CreateProductScreen extends StatefulWidget {
  final Product? product;

  const CreateProductScreen({super.key, this.product});

  @override
  State<CreateProductScreen> createState() => _CreateProductScreenState();
}

class _CreateProductScreenState extends State<CreateProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController barcodeController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController quantityController = TextEditingController();

  List<Supplier> _suppliers = [];
  int? _selectedSupplierId;

  @override
  void initState() {
    super.initState();
    _loadSuppliers();

    if (widget.product != null) {
      nameController.text = widget.product!.name;
      barcodeController.text = widget.product!.barcode ?? '';
      descriptionController.text = widget.product!.description ?? '';
      priceController.text = widget.product!.price.toString();
      quantityController.text = widget.product!.quantity.toString();
      _selectedSupplierId = widget.product!.supplierId;
    }
  }

  Future<void> _loadSuppliers() async {
    final suppliers = await DBHelper.getSuppliers();
    setState(() {
      _suppliers = suppliers;
    });
  }

  void _saveProduct() async {
    if (_formKey.currentState!.validate()) {
      final newProduct = Product(
        id: widget.product?.id,
        name: nameController.text.trim(),
        barcode: barcodeController.text.trim(),
        description: descriptionController.text.trim(),
        price: double.tryParse(priceController.text.trim()) ?? 0.0,
        quantity: int.tryParse(quantityController.text.trim()) ?? 0,
        supplierId: _selectedSupplierId,
      );

      if (widget.product == null) {
        await DBHelper.insertProduct(newProduct);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Producto creado exitosamente')),
        );
      } else {
        await DBHelper.updateProduct(newProduct);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Producto actualizado exitosamente')),
        );
      }

      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.product != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Editar Producto' : 'Nuevo Producto')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: nameController,
                decoration: InputDecoration(labelText: 'Nombre'),
                validator: (value) => value!.isEmpty ? 'Ingrese un nombre' : null,
              ),
              TextFormField(
                controller: barcodeController,
                decoration: InputDecoration(labelText: 'Código de Barras'),
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
                value: _selectedSupplierId,
                items: _suppliers.map((s) {
                  return DropdownMenuItem(
                    value: s.id,
                    child: Text(s.name),
                  );
                }).toList(),
                decoration: InputDecoration(labelText: 'Proveedor'),
                onChanged: (value) {
                  setState(() {
                    _selectedSupplierId = value;
                  });
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveProduct,
                child: Text(isEditing ? 'Actualizar' : 'Guardar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
