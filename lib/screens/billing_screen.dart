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
  TextEditingController _searchController = TextEditingController();
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
    setState(() {
      _clients = clients;
      _filteredClients = clients;
    });
  }

  void _filterClients() {
    final query = _searchController.text.trim();
    setState(() {
      _filteredClients = _clients
          .where((client) => client.phone.contains(query))
          .toList();
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Facturación')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Buscar cliente por teléfono',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: _filteredClients.length,
                itemBuilder: (_, index) {
                  final client = _filteredClients[index];
                  final isSelected = _selectedClient?.phone == client.phone;
                  return ListTile(
                    title: Text('${client.name} ${client.lastName}'),
                    subtitle: Text(client.phone),
                    tileColor: isSelected ? Colors.blue.shade100 : null,
                    onTap: () {
                      setState(() {
                        _selectedClient = client;
                        _searchController.text = client.phone;
                      });
                    },
                  );
                },
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _goToSalesScreen,
              child: Text('Continuar con factura'),
            ),
          ],
        ),
      ),
    );
  }
}
