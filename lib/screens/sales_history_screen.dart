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
      final isVoided = sale.isVoided;

      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: ListTile(
          title: Row(
            children: [
              Expanded(
                child: Text(
                  'Factura #${sale.id}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    decoration:
                        isVoided ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),

              // 🔴 Badge ANULADA
              if (isVoided)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red),
                  ),
                  child: const Text(
                    'ANULADA',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),

          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Fecha: ${DateFormat('yyyy-MM-dd').format(DateTime.parse(sale.date))}',
              ),

              // Fecha de anulación (opcional, muy útil en auditoría)
              if (isVoided && sale.voidedAt != null)
                Text(
                  'Anulada: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(sale.voidedAt!))}',
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
            ],
          ),

          trailing: Text(
            '\$${sale.total.toStringAsFixed(2)}',
            style: TextStyle(
              color: isVoided ? Colors.grey : Colors.black,
              fontWeight: FontWeight.w600,
            ),
          ),

          onTap: () async {
  final changed = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => SaleDetailScreen(sale: sale),
    ),
  );

  if (changed == true) {
    await _loadSales(); // <-- tu método que recarga la lista
  }
},

        ),
      );
    },
  ),
),

        ],
      ),
    );
  }
}
