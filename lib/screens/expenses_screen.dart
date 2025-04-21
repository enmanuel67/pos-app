import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import '../models/expense.dart';
import '../models/expense_entry.dart';
import '../screens/expense_history_screen.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({Key? key}) : super(key: key);

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  List<Expense> _expenses = [];

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    final data = await DBHelper.getExpenses();
    setState(() {
      _expenses = data;
    });
  }

  Future<void> _addExpense() async {
    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nuevo Gasto'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Nombre del gasto'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                await DBHelper.insertExpense(Expense(name: name));
                Navigator.pop(context);
                _loadExpenses();
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _registerExpenseAmount(Expense expense) async {
    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Registrar gasto: ${expense.name}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(hintText: 'Monto'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(controller.text.trim());
              if (amount != null && amount > 0) {
                final entry = ExpenseEntry(
                  expenseId: expense.id!,
                  amount: amount,
                  date: DateTime.now().toIso8601String(),
                );
                await DBHelper.insertExpenseEntry(entry);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Gasto registrado')),
                );
              }
            },
            child: const Text('Registrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gestión de Gastos')),
      body: _expenses.isEmpty
          ? const Center(child: Text('No hay gastos definidos'))
          : ListView.builder(
              itemCount: _expenses.length,
              itemBuilder: (_, index) {
                final expense = _expenses[index];
                return ListTile(
                  title: Text(expense.name),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _registerExpenseAmount(expense),
                );
              },
            ),
      floatingActionButton: Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    FloatingActionButton.extended(
      heroTag: 'history',
      icon: const Icon(Icons.history),
      label: const Text(''),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ExpenseHistoryScreen()),
        );
      },
    ),
    const SizedBox(height: 12),
    FloatingActionButton(
      heroTag: 'add',
      onPressed: _addExpense,
      child: const Icon(Icons.add),
    ),
  ],
),

    );
  }
}
