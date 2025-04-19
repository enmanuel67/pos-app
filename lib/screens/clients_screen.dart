import 'package:flutter/material.dart';
import '../models/client.dart';
import '../db/db_helper.dart';
import 'create_client_screen.dart';
import 'edit_client_screen.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  List<Client> clients = [];
  List<Client> filteredClients = [];
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  void _loadClients() async {
    final data = await DBHelper.getClients();
    setState(() {
      clients = data;
      filteredClients = data;
    });
  }

  void _searchClients(String query) {
    final results = clients.where((c) => c.name.toLowerCase().contains(query.toLowerCase())).toList();
    setState(() {
      filteredClients = results;
    });
  }

  void _deleteClient(int id) async {
    await DBHelper.deleteClient(id);
    _loadClients();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Cliente eliminado')),
    );
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
            Expanded(
              child: ListView.separated(
                itemCount: filteredClients.length,
                separatorBuilder: (_, __) => Divider(height: 1),
                itemBuilder: (context, index) {
                  final client = filteredClients[index];
                  return ListTile(
                    title: Text(client.name),
                    subtitle: Text(client.phone),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'edit') {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => EditClientScreen(client: client)),
                          );
                          if (result == true) _loadClients();
                        } else if (value == 'delete') {
                          _deleteClient(client.id!);
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
