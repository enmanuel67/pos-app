import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../helpers/printer_helper.dart';

class PrintTestScreen extends StatefulWidget {
  const PrintTestScreen({super.key});

  @override
  State<PrintTestScreen> createState() => _PrintTestScreenState();
}

class _PrintTestScreenState extends State<PrintTestScreen> {
  final GlobalKey _printKey = GlobalKey();

  Future<void> _print() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Test Impresión", style: TextStyle(color: Colors.black)),
        content: Container(
          color: Colors.white,
          child: RepaintBoundary(
            key: _printKey,
            child: _buildFactura(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cerrar", style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );

    await Future.delayed(const Duration(milliseconds: 600));

    final imageBytes = await PrinterHelper.captureWidgetAsImage(_printKey);

    if (imageBytes != null) {
      await PrinterHelper.printImage(imageBytes);
      await PrinterHelper.printNewLines(6);
    } else {
      print('❌ No se capturó la imagen para imprimir.');
    }
  }

  Widget _buildFactura() {
  return Container(
    color: Colors.white,
    padding: const EdgeInsets.all(4),
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, // 🔧 evita overflow
        children: [
          const Center(
            child: Column(
              children: [
                Text(
                  'Factura de Prueba',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
                Text('DECOYAMIX', style: TextStyle(color: Colors.black)),
                Text('Atilio Pérez, Cutupú, La Vega',
                    style: TextStyle(color: Colors.black)),
                Text('(frente al parque)', style: TextStyle(color: Colors.black)),
                Text('829-940-5937', style: TextStyle(color: Colors.black)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
            style: const TextStyle(color: Colors.black),
          ),
          const Text('Factura: #00001', style: TextStyle(color: Colors.black)),
          const Divider(color: Colors.black),
          const Text('Cliente: Prueba Uno', style: TextStyle(color: Colors.black)),
          const Text('Tel: 0000', style: TextStyle(color: Colors.black)),
          const Divider(color: Colors.black),
          const Text(
            'Producto    Cant.     Subtotal',
            style: TextStyle(color: Colors.black),
          ),
          const Divider(color: Colors.black),
          const Text(
            'Globos x2                    \$20.00',
            style: TextStyle(color: Colors.black),
          ),
          const Divider(color: Colors.black),
          const Text('Descuento total: \$0.00',
              style: TextStyle(color: Colors.black)),
          const Text('Total a pagar:   \$20.00',
              style: TextStyle(color: Colors.black)),
          const Text('Tipo de pago: Contado',
              style: TextStyle(color: Colors.black)),
          const Divider(color: Colors.black),
          const Center(
            child: Text(
              'Gracias por preferirnos',
              style: TextStyle(color: Colors.black),
            ),
          ),
          
        ],
        
      ),
      
    ),
  );
  
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Prueba de impresión")),
      body: Center(
        child: ElevatedButton(
          onPressed: _print,
          child: const Text("Imprimir factura de prueba"),
        ),
      ),
    );
  }
}
