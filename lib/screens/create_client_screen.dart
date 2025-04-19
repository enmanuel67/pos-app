import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import '../models/client.dart';

class CreateClientScreen extends StatefulWidget {
  final Client? client;

  const CreateClientScreen({super.key, this.client});

  @override
  State<CreateClientScreen> createState() => _CreateClientScreenState();
}

class _CreateClientScreenState extends State<CreateClientScreen> {
  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final lastNameController = TextEditingController();
  final phoneController = TextEditingController();
  final addressController = TextEditingController();
  final emailController = TextEditingController();
  final creditLimitController = TextEditingController();

  bool hasCredit = false;

  @override
  void initState() {
    super.initState();
    if (widget.client != null) {
      final c = widget.client!;
      nameController.text = c.name;
      lastNameController.text = c.lastName;
      phoneController.text = c.phone;
      addressController.text = c.address;
      emailController.text = c.email;
      hasCredit = c.hasCredit;
      if (c.hasCredit) {
        creditLimitController.text = c.creditLimit.toString();
      }
    }
  }

  void _saveClient() async {
    if (_formKey.currentState!.validate()) {
      final newClient = Client(
        id: widget.client?.id,
        name: nameController.text.trim(),
        lastName: lastNameController.text.trim(),
        phone: phoneController.text.trim(),
        address: addressController.text.trim(),
        email: emailController.text.trim(),
        hasCredit: hasCredit,
        creditLimit: hasCredit ? double.tryParse(creditLimitController.text.trim()) ?? 0.0 : 0.0,
      );

      if (widget.client == null) {
        await DBHelper.insertClient(newClient);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cliente creado.')));
      } else {
        await DBHelper.updateClient(newClient);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cliente actualizado.')));
      }

      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.client != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Editar Cliente' : 'Nuevo Cliente')),
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
                controller: lastNameController,
                decoration: InputDecoration(labelText: 'Apellido'),
                validator: (value) => value!.isEmpty ? 'Requerido' : null,
              ),
              TextFormField(
                controller: phoneController,
                decoration: InputDecoration(labelText: 'Teléfono'),
                keyboardType: TextInputType.phone,
                validator: (value) => value!.isEmpty ? 'Requerido' : null,
                enabled: !isEdit, // No editable si es edición
              ),
              TextFormField(
                controller: addressController,
                decoration: InputDecoration(labelText: 'Dirección'),
              ),
              TextFormField(
                controller: emailController,
                decoration: InputDecoration(labelText: 'Email'),
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<bool>(
                value: hasCredit,
                decoration: InputDecoration(labelText: '¿Tiene crédito?'),
                items: [
                  DropdownMenuItem(child: Text('No'), value: false),
                  DropdownMenuItem(child: Text('Sí'), value: true),
                ],
                onChanged: (value) {
                  setState(() {
                    hasCredit = value!;
                  });
                },
              ),
              if (hasCredit)
                TextFormField(
                  controller: creditLimitController,
                  decoration: InputDecoration(labelText: 'Límite de crédito'),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (hasCredit && (value == null || value.isEmpty)) {
                      return 'Ingrese el límite de crédito';
                    }
                    return null;
                  },
                ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveClient,
                child: Text(isEdit ? 'Actualizar' : 'Guardar'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
