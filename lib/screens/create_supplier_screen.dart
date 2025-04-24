import 'package:flutter/material.dart';
import '../models/supplier.dart';
import '../db/db_helper.dart';

class CreateSupplierScreen extends StatefulWidget {
  const CreateSupplierScreen({super.key});

  @override
  State<CreateSupplierScreen> createState() => _CreateSupplierScreenState();
}

class _CreateSupplierScreenState extends State<CreateSupplierScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController emailController = TextEditingController();

  void _saveSupplier() async {
  if (_formKey.currentState!.validate()) {
    final supplier = Supplier(
      name: nameController.text.trim(),
      phone: phoneController.text.trim(),
      description: descriptionController.text.trim(),
      address: addressController.text.trim(),
      email: emailController.text.trim(),
    );

    try {
      await DBHelper.insertSupplier(supplier);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Proveedor guardado exitosamente')),
      );

      Navigator.pop(context);
    } catch (e) {
      // 🔴 Aquí se muestra cualquier error que ocurra al guardar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar proveedor: $e')),
      );
    }
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Nuevo Proveedor')),
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
                controller: phoneController,
                decoration: InputDecoration(labelText: 'Teléfono'),
              ),
              TextFormField(
                controller: descriptionController,
                decoration: InputDecoration(labelText: 'Descripción'),
              ),
              TextFormField(
                controller: addressController,
                decoration: InputDecoration(labelText: 'Dirección'),
              ),
              TextFormField(
                controller: emailController,
                decoration: InputDecoration(labelText: 'Email'),
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveSupplier,
                child: Text('Guardar'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
