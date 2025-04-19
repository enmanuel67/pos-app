import 'package:flutter/material.dart';
import '../models/client.dart';
import '../db/db_helper.dart';

class EditClientScreen extends StatefulWidget {
  final Client client;

  const EditClientScreen({super.key, required this.client});

  @override
  State<EditClientScreen> createState() => _EditClientScreenState();
}

class _EditClientScreenState extends State<EditClientScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController nameController;
  late TextEditingController lastNameController;
  late TextEditingController phoneController;
  late TextEditingController addressController;
  late TextEditingController emailController;
  late TextEditingController creditLimitController;

  bool hasCredit = false;

  @override
  void initState() {
    super.initState();
    final c = widget.client;
    nameController = TextEditingController(text: c.name);
    lastNameController = TextEditingController(text: c.lastName);
    phoneController = TextEditingController(text: c.phone);
    addressController = TextEditingController(text: c.address);
    emailController = TextEditingController(text: c.email);
    creditLimitController = TextEditingController(
        text: c.hasCredit ? c.creditLimit.toString() : '');
    hasCredit = c.hasCredit;
  }

  void _updateClient() async {
    if (_formKey.currentState!.validate()) {
      final updatedClient = Client(
        id: widget.client.id,
        name: nameController.text.trim(),
        lastName: lastNameController.text.trim(),
        phone: phoneController.text.trim(),
        address: addressController.text.trim(),
        email: emailController.text.trim(),
        hasCredit: hasCredit,
        creditLimit: hasCredit ? double.tryParse(creditLimitController.text.trim()) ?? 0.0 : 0.0,
        credit: widget.client.credit, // No se modifica aquí
        creditAvailable: widget.client.creditAvailable, // Tampoco
      );

      await DBHelper.updateClient(updatedClient);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cliente actualizado.')),
      );

      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar Cliente')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (value) => value!.isEmpty ? 'Ingrese un nombre' : null,
              ),
              TextFormField(
                controller: lastNameController,
                decoration: const InputDecoration(labelText: 'Apellido'),
                validator: (value) => value!.isEmpty ? 'Ingrese un apellido' : null,
              ),
              TextFormField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Teléfono'),
                keyboardType: TextInputType.phone,
                enabled: false,
              ),
              TextFormField(
                controller: addressController,
                decoration: const InputDecoration(labelText: 'Dirección'),
              ),
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              DropdownButtonFormField<bool>(
                value: hasCredit,
                decoration: const InputDecoration(labelText: '¿Tiene crédito?'),
                items: const [
                  DropdownMenuItem(value: false, child: Text('No')),
                  DropdownMenuItem(value: true, child: Text('Sí')),
                ],
                onChanged: (val) {
                  setState(() {
                    hasCredit = val!;
                  });
                },
              ),
              if (hasCredit)
                TextFormField(
                  controller: creditLimitController,
                  decoration: const InputDecoration(labelText: 'Límite de crédito'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (hasCredit && (value == null || value.isEmpty)) {
                      return 'Ingrese el límite de crédito';
                    }
                    return null;
                  },
                ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _updateClient,
                child: const Text('Actualizar'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
