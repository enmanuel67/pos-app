import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import '../models/supplier.dart';
import 'create_supplier_screen.dart';
import 'edit_supplier_screen.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  List<Supplier> suppliers = [];
  List<Supplier> filteredSuppliers = [];
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
  }

  void _loadSuppliers() async {
    final data = await DBHelper.getSuppliers();
    setState(() {
      suppliers = data;
      filteredSuppliers = data;
    });
  }

  void _searchSuppliers(String query) {
    final results = suppliers
        .where((s) => s.name.toLowerCase().contains(query.toLowerCase()))
        .toList();
    setState(() {
      filteredSuppliers = results;
    });
  }

  Future<void> _deleteSupplier(int supplierId) async {
    final hasProducts = await DBHelper.supplierHasProducts(supplierId);
    if (hasProducts) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Este proveedor tiene productos asignados. No se puede eliminar.')),
      );
      return;
    }

    await DBHelper.deleteSupplier(supplierId);
    _loadSuppliers();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(title: Text('Proveedores')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: _searchSuppliers,
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: filteredSuppliers.length,
                separatorBuilder: (_, __) => Divider(height: 1),
                itemBuilder: (context, index) {
                  final supplier = filteredSuppliers[index];
                  return ListTile(
                    title: Text(supplier.name),
                    subtitle: Text(supplier.phone),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'edit') {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EditSupplierScreen(supplier: supplier),
                            ),
                          );
                          if (result == true) _loadSuppliers();
                        } else if (value == 'delete') {
                          await _deleteSupplier(supplier.id!);
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(value: 'edit', child: Text('Editar')),
                        PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => CreateSupplierScreen()),
            );
            _loadSuppliers();
          },
          child: Icon(Icons.add),
        ),
      ),
    );
  }
}
