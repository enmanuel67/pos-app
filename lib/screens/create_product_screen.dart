import 'package:flutter/material.dart';
import 'package:pos_app/models/product.dart';
import '../models/supplier.dart';
import '../db/db_helper.dart';

class CreateProductScreen extends StatefulWidget {
  final String? initialBarcode;

  const CreateProductScreen({super.key, this.initialBarcode});

  @override
  State<CreateProductScreen> createState() => _CreateProductScreenState();
}

class _CreateProductScreenState extends State<CreateProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final barcodeController = TextEditingController();
  final descriptionController = TextEditingController();
  final priceController = TextEditingController();
  final costController = TextEditingController();
  bool isRentable = false; // por defecto es No


  List<Supplier> suppliers = [];
  Supplier? selectedSupplier;
  String? selectedBusinessType; // 👈 Declarada aquí

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
    if (widget.initialBarcode != null) {
      barcodeController.text = widget.initialBarcode!;
    }
  }

  Future<void> _loadSuppliers() async {
    final result = await DBHelper.getSuppliers();
    setState(() {
      suppliers = result;
    });
  }

  Future<void> _saveProduct() async {
    if (_formKey.currentState!.validate()) {
      final newProduct = Product(
        name: nameController.text.trim(),
        barcode: barcodeController.text.trim(),
        description: descriptionController.text.trim(),
        price: double.tryParse(priceController.text.trim()) ?? 0.0,
        cost: double.tryParse(costController.text.trim()) ?? 0.0,
        quantity: 0, // Siempre inicia en 0
        supplierId: selectedSupplier?.id ?? 0,
        createdAt: DateTime.now().toIso8601String(),
        businessType: selectedBusinessType ?? 'A', // 👈 Guardamos el tipo de negocio
        isRentable: selectedBusinessType == 'Decoyamix' ? isRentable : null,
      );

      final productId = await DBHelper.insertProduct(newProduct);
      final createdProduct = newProduct.copyWith(id: productId);

      Navigator.pop(context, createdProduct);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo Producto')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (value) => value!.isEmpty ? 'Requerido' : null,
              ),
              TextFormField(
                controller: barcodeController,
                decoration: const InputDecoration(labelText: 'Código de barra'),
              ),
              TextFormField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Descripción'),
              ),
              TextFormField(
                controller: priceController,
                decoration: const InputDecoration(labelText: 'Precio de venta'),
                keyboardType: TextInputType.number,
              ),
              TextFormField(
                controller: costController,
                decoration: const InputDecoration(labelText: 'Costo unitario'),
                keyboardType: TextInputType.number,
              ),
              DropdownButtonFormField<Supplier>(
                value: selectedSupplier,
                decoration: const InputDecoration(labelText: 'Proveedor'),
                items: suppliers
                    .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                    .toList(),
                onChanged: (val) => setState(() => selectedSupplier = val),
              ),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Negocio'),
                value: selectedBusinessType,
                items: const [
                  DropdownMenuItem(value: 'Decoyamix', child: Text('Decoyamix')),
                  DropdownMenuItem(value: 'EnmaYami', child: Text('EnmaYami')),
                  DropdownMenuItem(value: 'Decoyamix(hogar)', child: Text('Decoyamix(hogar)')),
                ],
                onChanged: (val) => setState(() => selectedBusinessType = val),
                validator: (val) => val == null ? 'Selecciona un negocio' : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveProduct,
                child: const Text('Guardar'),
              ),
              if (selectedBusinessType == 'Decoyamix') ...[
  const SizedBox(height: 16),
  const Text('¿Este artículo es rentable?', style: TextStyle(fontWeight: FontWeight.bold)),
  Row(
    children: [
      Expanded(
        child: RadioListTile<bool>(
          title: const Text('Sí'),
          value: true,
          groupValue: isRentable,
          onChanged: (val) => setState(() => isRentable = val!),
        ),
      ),
      Expanded(
        child: RadioListTile<bool>(
          title: const Text('No'),
          value: false,
          groupValue: isRentable,
          onChanged: (val) => setState(() => isRentable = val!),
        ),
      ),
    ],
  ),
],

            ],
          ),
        ),
      ),
    );
  }
}
