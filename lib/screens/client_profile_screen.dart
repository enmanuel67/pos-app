import 'package:flutter/material.dart';
import '../models/client.dart';
import '../models/sale.dart';
import '../db/db_helper.dart';

class ClientProfileScreen extends StatefulWidget {
  final Client client;

  const ClientProfileScreen({super.key, required this.client});

  @override
  State<ClientProfileScreen> createState() => _ClientProfileScreenState();
}

class _ClientProfileScreenState extends State<ClientProfileScreen> {
  List<Sale> _creditSales = [];
  double _totalDebt = 0.0;

  @override
  void initState() {
    super.initState();
    _loadCreditSales();
  }

  Future<void> _loadCreditSales() async {
    final allSales = await DBHelper.getCreditSalesByClient(widget.client.phone);
    final creditSales = allSales.where((s) => s.isCredit).toList();
    final total = creditSales.fold(0.0, (sum, s) => sum + s.amountDue);

    setState(() {
      _creditSales = creditSales;
      _totalDebt = total;
    });
  }

  void _showPaymentDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Registrar pago'),
        content: Text('¿Qué tipo de pago desea registrar?'),
        actions: [
          TextButton(
            child: Text('Pago total'),
            onPressed: () {
              Navigator.pop(context);
              _processPayment(_totalDebt);
            },
          ),
          TextButton(
            child: Text('Monto personalizado'),
            onPressed: () {
              Navigator.pop(context);
              _showCustomAmountDialog();
            },
          ),
        ],
      ),
    );
  }

  void _showCustomAmountDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Ingrese monto a pagar'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: 'Monto'),
        ),
        actions: [
          TextButton(
            child: Text('Cancelar'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: Text('Aceptar'),
            onPressed: () {
              final value = double.tryParse(controller.text);
              Navigator.pop(context);
              if (value != null && value > 0) {
                _processPayment(value);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Monto inválido')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _processPayment(double amount) async {
    double remaining = amount;
    Map<int, double> affectedSales = {};

    for (var sale in _creditSales) {
      if (remaining <= 0) break;
      final payment = remaining >= sale.amountDue ? sale.amountDue : remaining;
      remaining -= payment;
      await DBHelper.markSaleAsPaid(sale.id!, payment);
      affectedSales[sale.id!] = payment;
    }

    final newCredit = (widget.client.credit - amount).clamp(0, widget.client.creditLimit);
    final newAvailable = (widget.client.creditAvailable + amount).clamp(0, widget.client.creditLimit);

    await DBHelper.updateClientCredit(
      widget.client.phone,
      newCredit.toDouble(),
      newAvailable.toDouble(),
    );

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pago registrado')));
    _loadCreditSales();
    _showReceipt(amount, affectedSales);
  }

  void _showReceipt(double amount, Map<int, double> affectedSales) {
    final now = DateTime.now();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Recibo de Pago'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cliente: ${widget.client.name} ${widget.client.lastName}'),
            Text('Teléfono: ${widget.client.phone}'),
            Text('Fecha: ${now.toLocal().toString().split('.')[0]}'),
            const Divider(),
            Text('Facturas afectadas:', style: TextStyle(fontWeight: FontWeight.bold)),
            ...affectedSales.entries.map((e) => Text('Factura #${e.key} - \$${e.value.toStringAsFixed(2)}')),
            const Divider(),
            Text('Monto pagado: \$${amount.toStringAsFixed(2)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cerrar'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.client;
    final creditDisponible = (c.creditLimit - _totalDebt).clamp(0.0, c.creditLimit);

    return Scaffold(
      appBar: AppBar(title: Text('Perfil de ${c.name} ${c.lastName}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text('Teléfono: ${c.phone}'),
            Text('Dirección: ${c.address}'),
            Text('Email: ${c.email}'),
            Text('Crédito disponible: \$${creditDisponible.toStringAsFixed(2)}'),
            Text('Deuda actual: \$${_totalDebt.toStringAsFixed(2)}'),
            SizedBox(height: 24),
            Text('Facturas a crédito:', style: TextStyle(fontWeight: FontWeight.bold)),
            ..._creditSales.map((sale) => ListTile(
              title: Text('Factura #${sale.id}'),
              subtitle: Text('Fecha: ${sale.date.split("T").first}'),
              trailing: Text('\$${sale.amountDue.toStringAsFixed(2)}'),
            )),
            SizedBox(height: 24),
            if (_totalDebt > 0)
              ElevatedButton(
                onPressed: _showPaymentDialog,
                child: Text('Registrar pago'),
              ),
          ],
        ),
      ),
    );
  }
}
