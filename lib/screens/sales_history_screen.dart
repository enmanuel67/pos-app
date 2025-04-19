import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/sale.dart';
import '../db/db_helper.dart';
import 'sale_detail_screen.dart';

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  List<Sale> _sales = [];
  List<Sale> _filteredSales = [];
  TextEditingController _searchController = TextEditingController();
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _loadSales();
    _searchController.addListener(_filterSales);
  }

  Future<void> _loadSales() async {
    final sales = await DBHelper.getAllSales();
    setState(() {
      _sales = sales;
      _filteredSales = sales;
    });
  }

  void _filterSales() {
    final query = _searchController.text;
    setState(() {
      _filteredSales =
          _sales.where((sale) {
            final matchId = query.isEmpty || sale.id.toString().contains(query);
            final matchDate =
                _selectedDate == null ||
                sale.date.startsWith(
                  DateFormat('yyyy-MM-dd').format(_selectedDate!),
                );
            return matchId && matchDate;
          }).toList();
    });
  }

  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
      _filterSales();
    }
  }

  void _clearDate() {
    setState(() {
      _selectedDate = null;
    });
    _filterSales();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Historial de Facturas')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar por ID',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                IconButton(icon: Icon(Icons.date_range), onPressed: _pickDate),
                if (_selectedDate != null)
                  IconButton(icon: Icon(Icons.clear), onPressed: _clearDate),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _filteredSales.length,
              itemBuilder: (_, index) {
                final sale = _filteredSales[index];
                return ListTile(
                  title: Text('Factura #${sale.id}'),
                  subtitle: Text(
                    'Fecha: ${DateFormat('yyyy-MM-dd').format(DateTime.parse(sale.date))}',
                  ),
                  trailing: Text('\$${sale.total.toStringAsFixed(2)}'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SaleDetailScreen(sale: sale),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
