import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import '../models/client.dart';
import 'client_profile_screen.dart';
import 'create_client_screen.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  List<Client> clients = [];
  List<Client> filteredClients = [];
  final TextEditingController searchController = TextEditingController();
  String selectedFilter = 'A-Z';
  Map<String, double> _debtsByClient = {};

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadClients() async {
    final data = await DBHelper.getClients();

    final debts = <String, double>{};
    for (final client in data) {
      if (client.phone.trim().isEmpty) continue;
      final sales = await DBHelper.getCreditSalesByClient(client.phone);
      final totalDebt = sales.fold<double>(0.0, (sum, s) => sum + s.amountDue);
      debts[client.phone] = totalDebt;
    }

    final sorted = _sortedClients(data, selectedFilter, debts);

    if (!mounted) return;
    setState(() {
      clients = data;
      _debtsByClient = debts;
      filteredClients = sorted;
    });
  }

  void _searchClients(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    final results = clients.where((client) {
      final fullName = '${client.name} ${client.lastName}'.trim().toLowerCase();
      final phone = client.phone.toLowerCase();
      return fullName.contains(normalizedQuery) ||
          phone.contains(normalizedQuery);
    }).toList();

    setState(() {
      filteredClients = results;
    });
  }

  List<Client> _sortedClients(
    List<Client> source,
    String filter,
    Map<String, double> debts,
  ) {
    final sorted = [...source];

    if (filter == 'A-Z') {
      sorted.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    } else if (filter == 'Z-A') {
      sorted.sort(
        (a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()),
      );
    } else if (filter == 'Deuda mas alta') {
      sorted.sort(
        (a, b) => (debts[b.phone] ?? 0).compareTo(debts[a.phone] ?? 0),
      );
    } else if (filter == 'Deuda mas vieja') {
      sorted.sort(
        (a, b) => (debts[b.phone] ?? 0).compareTo(debts[a.phone] ?? 0),
      );
    }

    return sorted;
  }

  void _applyFilter(String filter) {
    final sorted = _sortedClients(clients, filter, _debtsByClient);

    setState(() {
      selectedFilter = filter;
      filteredClients = sorted;
    });
  }

  double _getDebtForClient(String phone) {
    return _debtsByClient[phone] ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Clientes')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: 'Buscar cliente...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: _searchClients,
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: selectedFilter,
                    onChanged: (val) {
                      if (val != null) _applyFilter(val);
                    },
                    items: [
                      'A-Z',
                      'Z-A',
                      'Deuda mas alta',
                      'Deuda mas vieja',
                    ].map((label) {
                      return DropdownMenuItem(
                        value: label,
                        child: Text(label),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Filtro aplicado: $selectedFilter'),
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: filteredClients.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final client = filteredClients[index];
                  final debt = _getDebtForClient(client.phone);
                  final name = '${client.name} ${client.lastName}'.trim();

                  return ListTile(
                    title: Text(name.isEmpty ? 'Cliente sin nombre' : name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          client.phone.trim().isEmpty
                              ? 'Sin telefono'
                              : client.phone,
                        ),
                        if (debt > 0)
                          Text('Deuda: \$${debt.toStringAsFixed(2)}'),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ClientProfileScreen(client: client),
                        ),
                      ).then((_) => _loadClients());
                    },
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'edit') {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CreateClientScreen(client: client),
                            ),
                          );
                          if (result == true) _loadClients();
                        } else if (value == 'delete' && client.id != null) {
                          await DBHelper.deleteClient(client.id!);
                          _loadClients();
                        }
                      },
                      itemBuilder: (context) => const [
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
              MaterialPageRoute(builder: (_) => CreateClientScreen()),
            );
            _loadClients();
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
