import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

  // ✅ Último ingreso a inventario
  DateTime? _lastInventoryDate;
  bool _loadingLastInventoryDate = true;

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

    selectedBusinessType = widget.product.businessType ?? 'Decoyamix';

    _loadSuppliers();
    _loadLastInventoryDate();
  }

  Future<void> _loadSuppliers() async {
    final result = await DBHelper.getSuppliers();

    if (!mounted) return;
    setState(() {
      suppliers = result;

      if (suppliers.isNotEmpty) {
        selectedSupplier = suppliers.firstWhere(
          (s) => s.id == widget.product.supplierId,
          orElse: () => suppliers.first,
        );
      } else {
        selectedSupplier = null;
      }
    });
  }

  /// ✅ Trae la última fecha de ingreso a inventario desde inventory_entries
  Future<void> _loadLastInventoryDate() async {
    try {
      final id = widget.product.id;
      if (id == null) {
        if (!mounted) return;
        setState(() => _loadingLastInventoryDate = false);
        return;
      }

      final date = await DBHelper.getLastInventoryEntryDate(id);

      if (!mounted) return;
      setState(() {
        _lastInventoryDate = date;
        _loadingLastInventoryDate = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingLastInventoryDate = false);
    }
  }

  Future<void> _updateProduct() async {
    if (!_formKey.currentState!.validate()) return;

    if (selectedSupplier == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Debes seleccionar un proveedor')),
      );
      return;
    }

    final updated = Product(
      id: widget.product.id,
      name: nameController.text.trim(),
      barcode: barcodeController.text.trim(),
      description: descriptionController.text.trim(),
      price: double.tryParse(priceController.text.trim()) ?? 0.0,

      // 🔒 No se puede editar la cantidad aquí (se mantiene igual)
      quantity: widget.product.quantity,

      cost: widget.product.cost,
      supplierId: selectedSupplier!.id!,
      businessType: selectedBusinessType,

      // ✅ Mantener createdAt original (NO cambiarlo al editar)
      createdAt: widget.product.createdAt,

      // ✅ Mantener rentable tal cual
      isRentable: widget.product.isRentable,
    );

    await DBHelper.updateProduct(updated);

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  void dispose() {
    nameController.dispose();
    barcodeController.dispose();
    descriptionController.dispose();
    priceController.dispose();
    quantityController.dispose();
    costController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar Producto')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
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
  enabled: false, // 🔒 BLOQUEADO PARA TODOS
  decoration: const InputDecoration(
    labelText: 'Costo unitario',
    helperText: 'El costo se gestiona desde Inventario',
  ),
  keyboardType: TextInputType.number,
),


              TextFormField(
                controller: quantityController,
                enabled: false, // 🔒 BLOQUEADO PARA TODOS
                decoration: const InputDecoration(
                  labelText: 'Cantidad',
                  helperText: 'La cantidad se gestiona desde Inventario',
                ),
                keyboardType: TextInputType.number,
              ),

              // ✅ AVISO DE PRODUCTO RENTADO
              if (widget.product.isRentable == true)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: const [
                      Icon(Icons.repeat, color: Colors.blueGrey, size: 18),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Este producto es RENTADO (no afecta inventario)',
                          style: TextStyle(
                            color: Colors.blueGrey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 8),

              DropdownButtonFormField<Supplier>(
                value: selectedSupplier,
                decoration: const InputDecoration(labelText: 'Proveedor'),
                items: suppliers.map((s) {
                  return DropdownMenuItem(
                    value: s,
                    child: Text(s.name),
                  );
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
                validator: (val) => val == null ? 'Selecciona un negocio' : null,
              ),

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: _updateProduct,
                child: const Text('Actualizar'),
              ),

              // ✅ FECHA ÚLTIMO INGRESO (debajo del botón)
              const SizedBox(height: 12),
              if (_loadingLastInventoryDate)
                const Center(child: CircularProgressIndicator(strokeWidth: 2))
              else
                Center(
                  child: Text(
                    _lastInventoryDate == null
                        ? 'Último ingreso a inventario: (sin registros)'
                        : 'Último ingreso a inventario: ${DateFormat('yyyy-MM-dd HH:mm').format(_lastInventoryDate!)}',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
