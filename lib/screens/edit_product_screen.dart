import 'package:flutter/material.dart';
import 'package:pos_app/models/product.dart';
import '../models/supplier.dart';
import '../db/db_helper.dart';

class EditProductScreen extends StatefulWidget {
  final Product product;

  const EditProductScreen({super.key, required this.product});

  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController nameController;
  late TextEditingController barcodeController;
  late TextEditingController descriptionController;
  late TextEditingController priceController;
  late TextEditingController quantityController;
  late TextEditingController costController;
  late String selectedBusinessType;

  List<Supplier> suppliers = [];
  Supplier? selectedSupplier;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    nameController = TextEditingController(text: p.name);
    barcodeController = TextEditingController(text: p.barcode);
    descriptionController = TextEditingController(text: p.description);
    priceController = TextEditingController(text: p.price.toString());
    quantityController = TextEditingController(text: p.quantity.toString());
    costController = TextEditingController(text: p.cost.toString());
    _loadSuppliers();
    selectedBusinessType = widget.product.businessType ?? 'A';
  }

  Future<void> _loadSuppliers() async {
    final result = await DBHelper.getSuppliers();
    setState(() {
      suppliers = result;
      selectedSupplier = suppliers.firstWhere(
        (s) => s.id == widget.product.supplierId,
        orElse: () => suppliers.first,
      );
    });
  }

  Future<void> _updateProduct() async {
    if (_formKey.currentState!.validate()) {
      final updated = Product(
        id: widget.product.id,
        name: nameController.text.trim(),
        barcode: barcodeController.text.trim(),
        description: descriptionController.text.trim(),
        price: double.tryParse(priceController.text.trim()) ?? 0.0,
        quantity: int.tryParse(quantityController.text.trim()) ?? 0,
        cost: double.tryParse(costController.text.trim()) ?? 0.0,
        supplierId: selectedSupplier!.id!,
        createdAt: DateTime.now().toIso8601String(), // <-- AGREGA ESTA LÍNEA
        businessType: selectedBusinessType,
      );

      await DBHelper.updateProduct(updated);
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Editar Producto')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: nameController,
                decoration: InputDecoration(labelText: 'Nombre'),
                validator: (value) => value!.isEmpty ? 'Requerido' : null,
              ),
              TextFormField(
                controller: barcodeController,
                decoration: InputDecoration(labelText: 'Código de barra'),
              ),
              TextFormField(
                controller: descriptionController,
                decoration: InputDecoration(labelText: 'Descripción'),
              ),
              TextFormField(
                controller: priceController,
                decoration: InputDecoration(labelText: 'Precio de venta'),
                keyboardType: TextInputType.number,
              ),
              TextFormField(
                controller: costController,
                decoration: InputDecoration(labelText: 'Costo unitario'),
                keyboardType: TextInputType.number,
              ),
              TextFormField(
                controller: quantityController,
                decoration: InputDecoration(labelText: 'Cantidad'),
                keyboardType: TextInputType.number,
              ),
              DropdownButtonFormField<Supplier>(
                value: selectedSupplier,
                decoration: InputDecoration(labelText: 'Proveedor'),
                items:
                    suppliers.map((s) {
                      return DropdownMenuItem(value: s, child: Text(s.name));
                    }).toList(),
                onChanged: (val) {
                  setState(() => selectedSupplier = val);
                },
              ),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Negocio'),
                value: selectedBusinessType,
                items: const [
                  DropdownMenuItem(value: 'Decoyamix', child: Text('Decoyamix')),
                  DropdownMenuItem(value: 'EnmaYami', child: Text('EnmaYami')),
                  DropdownMenuItem(value: 'Decoyamix(hogar)', child: Text('Decoyamix(hogar)')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => selectedBusinessType = val);
                  }
                },
                validator:
                    (val) => val == null ? 'Selecciona un negocio' : null,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _updateProduct,
                child: Text('Actualizar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
