import 'package:flutter/material.dart';
import '../models/client.dart';
import '../db/db_helper.dart';
import 'sales_screen.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Client> _clients = [];
  List<Client> _filteredClients = [];
  Client? _selectedClient;

  @override
  void initState() {
    super.initState();
    _loadClients();
    _searchController.addListener(_filterClients);
  }

  Future<void> _loadClients() async {
    final clients = await DBHelper.getClients();
    if (!mounted) return;
    setState(() {
      _clients = clients;
      _filteredClients = clients;
    });
  }

  void _filterClients() {
    final query = _searchController.text.trim().toLowerCase();

    setState(() {
      _filteredClients = _clients.where((client) {
        final fullName = '${client.name} ${client.lastName}'.toLowerCase();
        return fullName.contains(query);
      }).toList();
    });
  }

  void _goToSalesScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SalesScreen(clientPhone: _selectedClient?.phone),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterClients);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Facturación')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Buscar cliente por nombre',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: _filteredClients.length,
                itemBuilder: (_, index) {
                  final client = _filteredClients[index];
                  final isSelected = _selectedClient?.phone == client.phone;

                  return ListTile(
                    title: Text('${client.name} ${client.lastName}'),
                    subtitle: Text(client.phone),
                    tileColor: isSelected ? Colors.blueAccent.withOpacity(0.15) : null,
                    onTap: () {
                      setState(() {
                        _selectedClient = client;
                        _searchController.text = '${client.name} ${client.lastName}';
                      });
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _goToSalesScreen,
              child: const Text('Continuar con factura'),
            ),
          ],
        ),
      ),
    );
  }
}
