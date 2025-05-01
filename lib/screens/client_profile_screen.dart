import 'package:flutter/material.dart';
import '../models/client.dart';
import '../models/sale.dart';
import '../db/db_helper.dart';
import 'package:intl/intl.dart';
import '../helpers/printer_helper.dart';

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

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pago registrado')));
    _loadCreditSales();
    _showReceiptWithPrintOption(amount, affectedSales);
  }

  // Nueva función para mostrar el recibo con opción de impresión
  // Modifica la función _showReceiptWithPrintOption para solucionar el problema de overflow

void _showReceiptWithPrintOption(double amount, Map<int, double> affectedSales) {
  final now = DateTime.now();
  final formattedDate = DateFormat('yyyy-MM-dd HH:mm').format(now);
  
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text('Recibo de Pago', textAlign: TextAlign.center),
      // Usa IntrinsicHeight para controlar la altura y evitar overflow
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
          // Limitar la altura máxima para evitar overflow
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: SingleChildScrollView(
          child: RepaintBoundary(
            key: _receiptKey,
            child: Container(
              color: Colors.white,
              padding: EdgeInsets.all(16),
              // Usar IntrinsicWidth para que el contenedor se ajuste al contenido
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
                  Text('No. Recibo: ${now.millisecondsSinceEpoch.toString().substring(5)}'),
                  Text('Fecha: $formattedDate'),
                  Divider(),
                  Text('Cliente: ${widget.client.name} ${widget.client.lastName}'),
                  Text('Teléfono: ${widget.client.phone}'),
                  Divider(),
                  Text('Facturas afectadas:', style: TextStyle(fontWeight: FontWeight.bold)),
                  // Limitar el número de facturas mostradas o usar ListView.builder si son muchas
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: affectedSales.entries.map((e) => Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Text('Factura #${e.key} - \$${e.value.toStringAsFixed(2)}'),
                    )).toList(),
                  ),
                  Divider(),
                  // Usar Wrap para que se ajuste si el espacio es limitado
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      Text('MONTO PAGADO:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('\$${amount.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  SizedBox(height: 8),
                  // Usar Wrap para que se ajuste si el espacio es limitado
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
            _printPaymentReceipt(amount, affectedSales, formattedDate);
          },
        ),
      ],
    ),
  );
}

// También modifica la función _printPaymentReceiptAsText para asegurar que el contenido
// se ajuste correctamente en la impresora térmica

Future<void> _printPaymentReceiptAsText(double amount, Map<int, double> affectedSales, String formattedDate) async {
  try {
    final receiptNumber = DateTime.now().millisecondsSinceEpoch.toString().substring(5);
    
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
  } catch (e) {
    throw Exception('Error al imprimir recibo: $e');
  }
}

  // Función para imprimir el recibo de pago
  Future<void> _printPaymentReceipt(double amount, Map<int, double> affectedSales, String formattedDate) async {
    try {
      // Mostrar indicador de progreso
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
      await _printPaymentReceiptAsText(amount, affectedSales, formattedDate);
      
      // Cerrar diálogo de progreso
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
                        Text('\$${creditDisponible.toStringAsFixed(2)}', 
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
                        Text('\$${_totalDebt.toStringAsFixed(2)}',
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
                      trailing: Text('\$${sale.amountDue.toStringAsFixed(2)}', 
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)
                      ),
                    ),
                  )).toList(),
                ),
            SizedBox(height: 24),
            if (_totalDebt > 0)
              ElevatedButton.icon(
                icon: Icon(Icons.payment),
                label: Text('Registrar pago'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _showPaymentDialog,
              ),
          ],
        ),
      ),
    );
  }
}