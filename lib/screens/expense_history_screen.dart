import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/db_helper.dart';

class ExpenseHistoryScreen extends StatefulWidget {
  const ExpenseHistoryScreen({Key? key}) : super(key: key);

  @override
  State<ExpenseHistoryScreen> createState() => _ExpenseHistoryScreenState();
}

class _ExpenseHistoryScreenState extends State<ExpenseHistoryScreen> {
  List<Map<String, dynamic>> _allExpenses = [];
  List<Map<String, dynamic>> _filteredExpenses = [];
  double _filteredTotal = 0.0;

  DateTime? _startDate;
  DateTime? _endDate;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadExpenseHistory();
  }

  Future<void> _loadExpenseHistory() async {
    final expenses = await DBHelper.getExpenseHistory();
    setState(() {
      _allExpenses = expenses;
      _applyFilters();
    });
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();

    final filtered = _allExpenses.where((expense) {
      final matchesSearch = expense['expense_name'].toLowerCase().contains(query);
      final date = DateTime.parse(expense['date']);
      final inDateRange = (_startDate == null || date.isAfter(_startDate!.subtract(const Duration(days: 1)))) &&
                          (_endDate == null || date.isBefore(_endDate!.add(const Duration(days: 1))));
      return matchesSearch && inDateRange;
    }).toList();

    final total = filtered.fold<double>(
      0.0,
      (sum, e) => sum + (e['amount'] as num).toDouble(),
    );

    setState(() {
      _filteredExpenses = filtered;
      _filteredTotal = total;
    });
  }

  Future<void> _selectDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2022),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
        _applyFilters();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd');

    return Scaffold(
      appBar: AppBar(title: const Text('Historial de Gastos')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Buscar gasto...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => _applyFilters(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _selectDate(true),
                    child: Text(_startDate == null ? 'Desde' : dateFormat.format(_startDate!)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _selectDate(false),
                    child: Text(_endDate == null ? 'Hasta' : dateFormat.format(_endDate!)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _filteredExpenses.isEmpty
                  ? const Center(child: Text('No se encontraron gastos.'))
                  : ListView.separated(
                      itemCount: _filteredExpenses.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (_, index) {
                        final e = _filteredExpenses[index];
                        return ListTile(
                          title: Text(e['expense_name']),
                          subtitle: Text('Fecha: ${dateFormat.format(DateTime.parse(e['date']))}'),
                          trailing: Text('\$${(e['amount'] as num).toStringAsFixed(2)}'),
                        );
                      },
                    ),
            ),
            const Divider(),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Total filtrado: \$${_filteredTotal.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
