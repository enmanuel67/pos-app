import 'package:flutter/material.dart';
import '../models/client.dart';
import '../db/db_helper.dart';
import 'create_client_screen.dart';
import 'client_profile_screen.dart';
import '../models/sale.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  List<Client> clients = [];
  List<Client> filteredClients = [];
  TextEditingController searchController = TextEditingController();
  String selectedFilter = 'A-Z';
  Map<String, double> _debtsByClient = {};

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  Future<void> _loadClients() async {
    final data = await DBHelper.getClients();

    final debts = <String, double>{};
    for (var client in data) {
      final sales = await DBHelper.getCreditSalesByClient(client.phone);
      final totalDebt = sales.fold<double>(0.0, (sum, s) => sum + s.amountDue);
      debts[client.phone] = totalDebt;
    }

    setState(() {
      clients = data;
      _debtsByClient = debts;
      _applyFilter(selectedFilter);
    });
  }

  void _searchClients(String query) {
    final results = clients.where(
      (c) => '${c.name} ${c.lastName}'.toLowerCase().contains(query.toLowerCase()),
    ).toList();

    setState(() {
      filteredClients = results;
    });
  }

  void _applyFilter(String filter) {
    List<Client> sorted = [...clients];
    if (filter == 'A-Z') {
      sorted.sort((a, b) => a.name.compareTo(b.name));
    } else if (filter == 'Z-A') {
      sorted.sort((a, b) => b.name.compareTo(a.name));
    } else if (filter == 'Deuda más alta') {
      sorted.sort((a, b) => (_debtsByClient[b.phone] ?? 0).compareTo(_debtsByClient[a.phone] ?? 0));
    } else if (filter == 'Deuda más vieja') {
      sorted.sort((a, b) => (_debtsByClient[b.phone] ?? 0).compareTo(_debtsByClient[a.phone] ?? 0));
    }

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
        appBar: AppBar(title: Text('Clientes')),
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
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                      'Deuda más alta',
                      'Deuda más vieja',
                    ].map((label) => DropdownMenuItem(
                      value: label,
                      child: Text(label),
                    )).toList(),
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
                separatorBuilder: (_, __) => Divider(height: 1),
                itemBuilder: (context, index) {
                  final client = filteredClients[index];
                  final debt = _getDebtForClient(client.phone);

                  return ListTile(
                    title: Text('${client.name} ${client.lastName}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(client.phone),
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
                        } else if (value == 'delete') {
                          await DBHelper.deleteClient(client.id!);
                          _loadClients();
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
              MaterialPageRoute(builder: (_) => CreateClientScreen()),
            );
            _loadClients();
          },
          child: Icon(Icons.add),
        ),
      ),
    );
  }
}
