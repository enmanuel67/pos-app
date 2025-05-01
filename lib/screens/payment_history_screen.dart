import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/client.dart';
import '../db/db_helper.dart';
import '../helpers/printer_helper.dart';

class PaymentHistoryScreen extends StatefulWidget {
  final Client client;

  const PaymentHistoryScreen({Key? key, required this.client}) : super(key: key);

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  List<Map<String, dynamic>> _payments = [];
  bool _isLoading = true;
  DateTime? _startDate;
  DateTime? _endDate;
  
  @override
  void initState() {
    super.initState();
    _loadPaymentHistory();
  }
  
  Future<void> _loadPaymentHistory() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      if (_startDate != null && _endDate != null) {
        // Filtrar por rango de fechas
        final payments = await DBHelper.getPaymentHistoryByDateRange(
          widget.client.phone, 
          _startDate!, 
          _endDate!
        );
        setState(() {
          _payments = payments;
        });
      } else {
        // Cargar todos los pagos
        final payments = await DBHelper.getPaymentHistoryByClient(widget.client.phone);
        setState(() {
          _payments = payments;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar historial: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final initialDate = isStart ? _startDate ?? DateTime.now() : _endDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          // Si la fecha de inicio es posterior a la fecha de fin, actualizar la fecha de fin
          if (_endDate != null && picked.isAfter(_endDate!)) {
            _endDate = picked;
          }
        } else {
          _endDate = picked;
          // Si la fecha de fin es anterior a la fecha de inicio, actualizar la fecha de inicio
          if (_startDate != null && picked.isBefore(_startDate!)) {
            _startDate = picked;
          }
        }
      });
    }
  }
  
  Future<void> _applyDateFilter() async {
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Por favor selecciona las fechas de inicio y fin')),
      );
      return;
    }
    
    await _loadPaymentHistory();
  }
  
  Future<void> _clearFilter() async {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
    
    await _loadPaymentHistory();
  }
  
  void _viewPaymentDetail(Map<String, dynamic> payment) {
    // Convertir el string JSON a un mapa para las facturas afectadas
    final affectedSalesString = payment['affected_sales'] as String;
    final Map<String, dynamic> affectedSalesJson = jsonDecode(affectedSalesString);
    
    // Convertir las claves string a enteros y los valores a double
    final Map<int, double> affectedSales = {};
    affectedSalesJson.forEach((key, value) {
      final intKey = int.parse(key);
      final doubleValue = value is double ? value : double.parse(value.toString());
      affectedSales[intKey] = doubleValue;
    });
    
    final paymentDate = DateTime.parse(payment['payment_date']);
    final formattedDate = DateFormat('yyyy-MM-dd HH:mm').format(paymentDate);
    
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Detalle de Pago', textAlign: TextAlign.center),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  'RECIBO #${payment['receipt_number']}',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(height: 8),
              Text('Cliente: ${widget.client.name} ${widget.client.lastName}'),
              Text('Fecha: $formattedDate'),
              Text('Monto: \$${payment['amount'].toStringAsFixed(2)}'),
              Divider(),
              Text('Facturas afectadas:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...affectedSales.entries.map((e) => Padding(
                padding: EdgeInsets.only(left: 8),
                child: Text('Factura #${e.key} - \$${e.value.toStringAsFixed(2)}'),
              )).toList(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cerrar'),
          ),
          ElevatedButton.icon(
            icon: Icon(Icons.print),
            label: Text('Reimprimir'),
            onPressed: () => _reprintReceipt(payment, affectedSales),
          ),
        ],
      ),
    );
  }
  
  Future<void> _reprintReceipt(Map<String, dynamic> payment, Map<int, double> affectedSales) async {
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
                Text("Reimprimiendo recibo..."),
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
      
      // Reimprimir el recibo
      await _printHistoricalReceipt(payment, affectedSales);
      
      // Cerrar diálogo de progreso
      Navigator.pop(context);
      
      // Cerrar diálogo de detalle
      Navigator.pop(context);
      
      // Mensaje de éxito
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Recibo reimpreso correctamente')),
      );
    } catch (e) {
      // Cerrar diálogo de progreso si hay error
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      print('❌ Error al reimprimir recibo: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al reimprimir el recibo: $e')),
      );
    }
  }
  
  Future<void> _printHistoricalReceipt(Map<String, dynamic> payment, Map<int, double> affectedSales) async {
    try {
      final amount = payment['amount'] as double;
      final receiptNumber = payment['receipt_number'] as String;
      final paymentDate = DateTime.parse(payment['payment_date']);
      final formattedDate = DateFormat('yyyy-MM-dd HH:mm').format(paymentDate);
      
      // Imprimir encabezado
      await PrinterHelper.bluetooth.printCustom("DECOYAMIX", 1, 1);
      await PrinterHelper.bluetooth.printCustom("calle Atilio Pérez, Cutupú, La Vega", 0, 1);
      await PrinterHelper.bluetooth.printCustom("(frente al parque)", 0, 1);
      await PrinterHelper.bluetooth.printCustom("829-940-5937", 0, 1);
      await PrinterHelper.bluetooth.printNewLine();
      
      // Imprimir información del recibo con marca de reimpresión
      await PrinterHelper.bluetooth.printCustom("*** REIMPRESIÓN ***", 1, 1);
      await PrinterHelper.bluetooth.printCustom("RECIBO DE PAGO", 1, 1);
      await PrinterHelper.bluetooth.printCustom("No. Recibo: $receiptNumber", 0, 0);
      await PrinterHelper.bluetooth.printCustom("Fecha original: $formattedDate", 0, 0);
      await PrinterHelper.bluetooth.printCustom("Reimpreso: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}", 0, 0);
      await PrinterHelper.bluetooth.printCustom("--------------------------------", 0, 1);
      
      // Información del cliente
      await PrinterHelper.bluetooth.printCustom("Cliente: ${widget.client.name} ${widget.client.lastName}", 0, 0);
      await PrinterHelper.bluetooth.printCustom("Teléfono: ${widget.client.phone}", 0, 0);
      await PrinterHelper.bluetooth.printCustom("--------------------------------", 0, 1);
      
      // Facturas afectadas
      await PrinterHelper.bluetooth.printCustom("FACTURAS AFECTADAS:", 0, 0);
      for (var entry in affectedSales.entries) {
        String line = "Factura #${entry.key} - \$${entry.value.toStringAsFixed(2)}";
        if (line.length > 32) {
          line = line.substring(0, 32);
        }
        await PrinterHelper.bluetooth.printCustom(line, 0, 0);
      }
      
      await PrinterHelper.bluetooth.printCustom("--------------------------------", 0, 1);
      
      // Montos
      String montoText = "MONTO PAGADO: \$${amount.toStringAsFixed(2)}";
      await PrinterHelper.bluetooth.printCustom(montoText, 1, 0);
      
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

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd');
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Historial de Pagos'),
      ),
      body: Column(
        children: [
          // Filtro de fechas
          Card(
            margin: EdgeInsets.all(8),
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Filtrar por fecha', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: Icon(Icons.calendar_today),
                          label: Text(_startDate == null ? 'Desde' : dateFormat.format(_startDate!)),
                          onPressed: () => _selectDate(context, true),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: Icon(Icons.calendar_today),
                          label: Text(_endDate == null ? 'Hasta' : dateFormat.format(_endDate!)),
                          onPressed: () => _selectDate(context, false),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        icon: Icon(Icons.clear),
                        label: Text('Limpiar'),
                        onPressed: _clearFilter,
                      ),
                      ElevatedButton.icon(
                        icon: Icon(Icons.filter_alt),
                        label: Text('Filtrar'),
                        onPressed: _applyDateFilter,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // Lista de pagos
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _payments.isEmpty
                    ? Center(
                        child: Text(
                          'No se encontraron pagos',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _payments.length,
                        itemBuilder: (context, index) {
                          final payment = _payments[index];
                          final paymentDate = DateTime.parse(payment['payment_date']);
                          
                          return Card(
                            margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: ListTile(
                              title: Text('Recibo #${payment['receipt_number']}'),
                              subtitle: Text(
                                'Fecha: ${DateFormat('yyyy-MM-dd HH:mm').format(paymentDate)}',
                              ),
                              trailing: Text(
                                '\$${payment['amount'].toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.green,
                                ),
                              ),
                              onTap: () => _viewPaymentDetail(payment),
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