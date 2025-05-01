import 'package:flutter/material.dart';
import '../models/client.dart';
import '../models/sale.dart';
import '../db/db_helper.dart';
import 'package:intl/intl.dart';
import '../helpers/printer_helper.dart';
import 'payment_history_screen.dart'; // Importar la pantalla de historial de pagos


class ClientProfileScreen extends StatefulWidget {
  final Client client;

  const ClientProfileScreen({super.key, required this.client});

  @override
  State<ClientProfileScreen> createState() => _ClientProfileScreenState();
}

class _ClientProfileScreenState extends State<ClientProfileScreen> {
  List<Sale> _creditSales = [];
  double _totalDebt = 0.0;
  final GlobalKey _receiptKey = GlobalKey();

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

    // Generar un número de recibo único
    final receiptNumber = DateTime.now().millisecondsSinceEpoch.toString().substring(5);
    
    // Guardar el pago en el historial
    await DBHelper.savePaymentHistory(
      widget.client.phone, 
      amount,
      receiptNumber,
      affectedSales
    );

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pago registrado')));
    _loadCreditSales();
    _showReceiptWithPrintOption(amount, affectedSales, receiptNumber);
  }

  void _showReceiptWithPrintOption(double amount, Map<int, double> affectedSales, String receiptNumber) {
    final now = DateTime.now();
    final formattedDate = DateFormat('yyyy-MM-dd HH:mm').format(now);
    
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Recibo de Pago', textAlign: TextAlign.center),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8,
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: SingleChildScrollView(
            child: RepaintBoundary(
              key: _receiptKey,
              child: Container(
                color: Colors.white,
                padding: EdgeInsets.all(16),
                width: double.infinity,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Column(
                        children: [
                          Text(
                            'DECOYAMIX',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text('calle Atilio Pérez, Cutupú, La Vega'),
                          Text('(frente al parque)'),
                          Text('829-940-5937'),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),
                    Text('RECIBO DE PAGO', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('No. Recibo: $receiptNumber'),
                    Text('Fecha: $formattedDate'),
                    Divider(),
                    Text('Cliente: ${widget.client.name} ${widget.client.lastName}'),
                    Text('Teléfono: ${widget.client.phone}'),
                    Divider(),
                    Text('Facturas afectadas:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: affectedSales.entries.map((e) => Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Text('Factura #${e.key} - \$${e.value.toStringAsFixed(2)}'),
                      )).toList(),
                    ),
                    Divider(),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        Text('MONTO PAGADO:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('\$${amount.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    SizedBox(height: 8),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        Text('Nuevo balance:'),
                        Text('\$${_totalDebt.toStringAsFixed(2)}'),
                      ],
                    ),
                    SizedBox(height: 16),
                    Center(child: Text('¡Gracias por su pago!')),
                  ],
                ),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text('Cerrar'),
          ),
          ElevatedButton.icon(
            icon: Icon(Icons.print),
            label: Text('Imprimir recibo'),
            onPressed: () {
              _printPaymentReceipt(amount, affectedSales, formattedDate, receiptNumber);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _printPaymentReceiptAsText(double amount, Map<int, double> affectedSales, 
      String formattedDate, String receiptNumber) async {
    try {
      // Imprimir encabezado
      await PrinterHelper.bluetooth.printCustom("DECOYAMIX", 1, 1);
      await PrinterHelper.bluetooth.printCustom("calle Atilio Pérez, Cutupú, La Vega", 0, 1);
      await PrinterHelper.bluetooth.printCustom("(frente al parque)", 0, 1);
      await PrinterHelper.bluetooth.printCustom("829-940-5937", 0, 1);
      await PrinterHelper.bluetooth.printNewLine();
      
      // Imprimir información del recibo
      await PrinterHelper.bluetooth.printCustom("RECIBO DE PAGO", 1, 1);
      await PrinterHelper.bluetooth.printCustom("No. Recibo: $receiptNumber", 0, 0);
      await PrinterHelper.bluetooth.printCustom("Fecha: $formattedDate", 0, 0);
      await PrinterHelper.bluetooth.printCustom("--------------------------------", 0, 1);
      
      // Información del cliente
      await PrinterHelper.bluetooth.printCustom("Cliente: ${widget.client.name} ${widget.client.lastName}", 0, 0);
      await PrinterHelper.bluetooth.printCustom("Teléfono: ${widget.client.phone}", 0, 0);
      await PrinterHelper.bluetooth.printCustom("--------------------------------", 0, 1);
      
      // Facturas afectadas
      await PrinterHelper.bluetooth.printCustom("FACTURAS AFECTADAS:", 0, 0);
      for (var entry in affectedSales.entries) {
        // Acortar el texto si es necesario para evitar desbordamiento
        String line = "Factura #${entry.key} - \$${entry.value.toStringAsFixed(2)}";
        if (line.length > 32) { // 32 caracteres es típico para impresoras térmicas pequeñas
          line = line.substring(0, 32);
        }
        await PrinterHelper.bluetooth.printCustom(line, 0, 0);
      }
      
      await PrinterHelper.bluetooth.printCustom("--------------------------------", 0, 1);
      
      // Montos - asegúrate de que sean cortos
      String montoText = "MONTO PAGADO: \$${amount.toStringAsFixed(2)}";
      await PrinterHelper.bluetooth.printCustom(montoText, 1, 0);
      
      String balanceText = "Nuevo balance: \$${_totalDebt.toStringAsFixed(2)}";
      await PrinterHelper.bluetooth.printCustom(balanceText, 0, 0);
      
      await PrinterHelper.bluetooth.printNewLine();
      
      // Pie de página
      await PrinterHelper.bluetooth.printCustom("¡Gracias por su pago!", 0, 1);
      await PrinterHelper.bluetooth.printNewLine();
      await PrinterHelper.bluetooth.printNewLine();
      await PrinterHelper.bluetooth.printNewLine();
      await PrinterHelper.bluetooth.printNewLine();
      await PrinterHelper.bluetooth.printNewLine(); // Más papel para facilitar el corte
    } catch (e) {
      throw Exception('Error al imprimir recibo: $e');
    }
  }

  Future<void> _printPaymentReceipt(double amount, Map<int, double> affectedSales, 
      String formattedDate, String receiptNumber) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text("Imprimiendo recibo..."),
              ],
            ),
          );
        },
      );
      
      // Verificar conexión a la impresora
      final connected = await PrinterHelper.connectToPrinter();
      if (!connected) {
        Navigator.pop(context); // Cerrar diálogo de progreso
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo conectar a la impresora')),
        );
        return;
      }
      
      // Imprimir usando el método de texto directo
      await _printPaymentReceiptAsText(amount, affectedSales, formattedDate, receiptNumber);
      
      // Cerrar diálogo de progreso
      Navigator.pop(context);
      
      // Cerrar diálogo de vista previa
      Navigator.pop(context);
      
      // Mensaje de éxito
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Recibo impreso correctamente')),
      );
    } catch (e) {
      // Cerrar diálogo de progreso si hay error
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      print('❌ Error al imprimir recibo: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al imprimir el recibo: $e')),
      );
    }
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
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Información personal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    SizedBox(height: 8),
                    Text('Teléfono: ${c.phone}'),
                    Text('Dirección: ${c.address}'),
                    Text('Email: ${c.email}'),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Información de crédito', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Crédito disponible:'),
                        Text('\$' + creditDisponible.toStringAsFixed(2), 
                          style: TextStyle(
                            color: creditDisponible > 0 ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Deuda actual:'),
                        Text('\$' + _totalDebt.toStringAsFixed(2),
                          style: TextStyle(
                            color: _totalDebt > 0 ? Colors.red : Colors.green,
                            fontWeight: FontWeight.bold
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            // Botones de acción
            SizedBox(height: 16),
            Row(
              children: [
                // Botón para ver historial de pagos
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.history),
                    label: Text('Historial de Pagos'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PaymentHistoryScreen(
                            client: widget.client,
                          ),
                        ),
                      ).then((_) => _loadCreditSales()); // Recargar al volver
                    },
                  ),
                ),
                
                // Si hay deuda, mostrar el botón de registrar pago
                if (_totalDebt > 0) ...[
                  SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.payment),
                      label: Text('Registrar Pago'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _showPaymentDialog,
                    ),
                  ),
                ],
              ],
            ),
            
            SizedBox(height: 24),
            Text('Facturas a crédito:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(height: 8),
            _creditSales.isEmpty 
              ? Center(child: Text('No hay facturas pendientes', style: TextStyle(color: Colors.grey)))
              : Column(
                  children: _creditSales.map((sale) => Card(
                    margin: EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text('Factura #${sale.id}'),
                      subtitle: Text('Fecha: ${sale.date.split("T").first}'),
                      trailing: Text('\$' + sale.amountDue.toStringAsFixed(2), 
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)
                      ),
                    ),
                  )).toList(),
                ),
          ],
        ),
      ),
    );
  }
}