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
  
  // Mapa para almacenar la deuda actual de cada cliente
  Map<String, double> _clientDebts = {};

  @override
  void initState() {
    super.initState();
    _loadClients();
    _searchController.addListener(_filterClients);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterClients);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadClients() async {
    final clients = await DBHelper.getClients();
    
    // Cargar la deuda actual de cada cliente
    for (var client in clients) {
      final creditSales = await DBHelper.getCreditSalesByClient(client.phone);
      final debt = creditSales.where((s) => s.isCredit).fold(0.0, (sum, s) => sum + s.amountDue);
      _clientDebts[client.phone] = debt;
    }
    
    setState(() {
      _clients = clients;
      _filteredClients = clients;
    });
  }

  void _filterClients() {
    final query = _searchController.text.trim().toLowerCase();

    setState(() {
      if (query.isEmpty) {
        _filteredClients = _clients;
        return;
      }

      _filteredClients = _clients.where((c) {
        final name = (c.name).toLowerCase();
        final last = (c.lastName).toLowerCase();
        final phone = (c.phone).toLowerCase();

        return name.contains(query) ||
            last.contains(query) ||
            ('$name $last').contains(query) ||
            phone.contains(query);
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

  // ✅ Soporta int/bool/string/null
  bool _isCreditEnabled(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is int) return v == 1;
    if (v is num) return v.toInt() == 1;
    if (v is String) {
      final s = v.trim().toLowerCase();
      return s == '1' || s == 'true' || s == 'yes' || s == 'si';
    }
    return false;
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  Widget _buildCreditInfo(Client client) {
    final hasCredit = _isCreditEnabled(client.hasCredit);

    if (!hasCredit) {
      return Row(
        children: const [
          Icon(Icons.block, size: 18, color: Colors.grey),
          SizedBox(width: 6),
          Text(
            'Sin crédito',
            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
          ),
        ],
      );
    }

    // ✅ Calcular deuda actual y crédito disponible igual que en client_profile_screen
    final debt = _clientDebts[client.phone] ?? 0.0;
    final limit = _toDouble(client.creditLimit);
    final available = (limit - debt).clamp(0.0, limit);

    final availableColor = available <= 0 ? Colors.red : Colors.green;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.credit_card, size: 18, color: availableColor),
            const SizedBox(width: 6),
            Text(
              'Disponible: \$${available.toStringAsFixed(2)} / \$${limit.toStringAsFixed(2)}',
              style: TextStyle(
                color: availableColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          'Deuda actual: \$${debt.toStringAsFixed(2)}',
          style: const TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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
              decoration: const InputDecoration(
                labelText: 'Buscar cliente por nombre o teléfono',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: _filteredClients.length,
                itemBuilder: (_, index) {
                  final client = _filteredClients[index];
                  final isSelected = _selectedClient?.phone == client.phone;

                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected
                            ? Colors.blue.shade300
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: ListTile(
                      title: Text(
                        '${client.name} ${client.lastName}'.trim(),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Tel: ${client.phone}'),
                            const SizedBox(height: 6),
                            _buildCreditInfo(client),
                          ],
                        ),
                      ),
                      tileColor: isSelected ? Colors.blue.shade50 : null,
                      onTap: () {
                        setState(() {
                          _selectedClient = client;
                          // ✅ NO forzamos el texto al teléfono (para seguir buscando por nombre)
                        });
                      },
                    ),
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