import 'package:flutter/material.dart';
import '../models/supplier.dart';
import '../db/db_helper.dart';

class EditSupplierScreen extends StatefulWidget {
  final Supplier supplier;

  const EditSupplierScreen({super.key, required this.supplier});

  @override
  State<EditSupplierScreen> createState() => _EditSupplierScreenState();
}

class _EditSupplierScreenState extends State<EditSupplierScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController nameController;
  late TextEditingController phoneController;
  late TextEditingController descriptionController;
  late TextEditingController addressController;
  late TextEditingController emailController;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.supplier.name);
    phoneController = TextEditingController(text: widget.supplier.phone);
    descriptionController = TextEditingController(text: widget.supplier.description);
    addressController = TextEditingController(text: widget.supplier.address);
    emailController = TextEditingController(text: widget.supplier.email);
  }

  void _updateSupplier() async {
    if (_formKey.currentState!.validate()) {
      final updated = Supplier(
        id: widget.supplier.id,
        name: nameController.text,
        phone: phoneController.text,
        description: descriptionController.text,
        address: addressController.text,
        email: emailController.text,
      );
      await DBHelper.updateSupplier(updated);
      Navigator.pop(context, true); // para recargar la lista
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Editar Proveedor')),
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
              TextFormField(controller: phoneController, decoration: InputDecoration(labelText: 'Teléfono')),
              TextFormField(controller: descriptionController, decoration: InputDecoration(labelText: 'Descripción')),
              TextFormField(controller: addressController, decoration: InputDecoration(labelText: 'Dirección')),
              TextFormField(controller: emailController, decoration: InputDecoration(labelText: 'Email')),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _updateSupplier,
                child: Text('Guardar cambios'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
