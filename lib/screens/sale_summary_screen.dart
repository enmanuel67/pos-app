import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:pos_app/db/db_helper.dart';
import 'package:pos_app/helpers/printer_helper.dart';
import 'package:pos_app/models/client.dart';
import 'package:pos_app/models/product.dart';
import 'package:pos_app/models/sale.dart';
import 'package:pos_app/models/sale_item.dart';

class SaleSummaryScreen extends StatefulWidget {
  final Map<Product, int> selectedProducts;
  final String? clientPhone;
  final bool isCredit;

  const SaleSummaryScreen({
    Key? key,
    required this.selectedProducts,
    this.clientPhone,
    required this.isCredit,
  }) : super(key: key);

  @override
  State<SaleSummaryScreen> createState() => _SaleSummaryScreenState();
}

class _SaleSummaryScreenState extends State<SaleSummaryScreen> {
  final GlobalKey _printKey = GlobalKey();
  late Map<Product, int> _products;
  Map<int, double> _discounts = {};
  double _total = 0.0;
  Client? _client;
  int? _generatedSaleId;
  bool _isRendering = false; // Flag para controlar el renderizado

  @override
  void initState() {
    super.initState();
    _products = Map.from(widget.selectedProducts);
    _calculateTotal();
    _loadClient();
  }

  void _calculateTotal() {
    _total = 0.0;
    _products.forEach((product, qty) {
      final discount = _discounts[product.id] ?? 0.0;
      _total += (product.price - discount) * qty;
    });
    setState(() {});
  }

  void _changeQuantity(Product product, int delta) {
    final currentQty = _products[product] ?? 0;
    final newQty = currentQty + delta;
    if (delta > 0 && newQty > product.quantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Stock insuficiente para ${product.name}')),
      );
      return;
    }
    setState(() {
      if (newQty <= 0) {
        _products.remove(product);
      } else {
        _products[product] = newQty;
      }
      _calculateTotal();
    });
  }

  void _editDiscount(Product product) {
    final controller = TextEditingController(
      text: (_discounts[product.id] ?? 0.0).toString(),
    );
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Descuento para ${product.name}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: 'Descuento por unidad'),
        ),
        actions: [
          TextButton(
            child: Text('Cancelar'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: Text('Aplicar'),
            onPressed: () {
              final value = double.tryParse(controller.text.trim()) ?? 0.0;
              Navigator.pop(context);
              setState(() {
                _discounts[product.id!] = value;
                _calculateTotal();
              });
            },
          ),
        ],
      ),
    );
  }

  Future<void> _loadClient() async {
    if (widget.clientPhone != null) {
      final result = await DBHelper.getClientByPhone(widget.clientPhone!);
      setState(() => _client = result);
    }
  }

  Widget _buildInvoice() {
    final totalDiscount = _products.entries.fold(0.0, (sum, entry) {
      final discount = _discounts[entry.key.id] ?? 0.0;
      return sum + (discount * entry.value);
    });

    return Material(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Factura', style: TextStyle(fontWeight: FontWeight.bold)),
            const Text('DECOYAMIX'),
            const Text('calle Atilio Pérez, Cutupú, La Vega'),
            const Text('(frente al parque)'),
            const Text('829-940-5937'),
            const SizedBox(height: 10),
            Text(DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())),
            Text('Factura: #${(_generatedSaleId?.toString().padLeft(5, '0')) ?? "-----"}'),
            const Divider(),
            Text('Cliente: ${_client != null ? '${_client!.name} ${_client!.lastName}' : 'Desconocido'}'),
            Text('Tel: ${_client?.phone ?? 'Sin teléfono'}'),
            const Divider(),
            const Text('Producto        Cant.   Subtotal'),
            const Divider(),
            ..._products.entries.map((entry) {
              final product = entry.key;
              final qty = entry.value;
              final discount = _discounts[product.id] ?? 0.0;
              final subtotal = ((product.price - discount) * qty).toStringAsFixed(2);
              return Text('${product.name} x$qty   \$${subtotal}');
            }),
            const Divider(),
            Text('Descuento total: \$${totalDiscount.toStringAsFixed(2)}'),
            Text('Total a pagar: \$${_total.toStringAsFixed(2)}'),
            Text(widget.isCredit ? 'Tipo de pago: Crédito' : 'Tipo de pago: Contado'),
            const Divider(),
            const Text('Gracias por preferirnos'),
          ],
        ),
      ),
    );
  }
  
  // NUEVA FUNCIÓN: renderizar y capturar factura de forma adecuada
  Future<Uint8List?> _renderAndCaptureInvoice() async {
    setState(() => _isRendering = true);
    
    // Construir un widget off-screen pero con tamaño definido
    final renderObject = RepaintBoundary(
      key: _printKey,
      child: Container(
        // Ancho aproximado para impresora térmica de 58mm (a 180 DPI)
        width: 384,
        child: _buildInvoice(),
      ),
    );
    
    // Crear un contexto de renderizado off-screen
    final BuildContext offScreenContext = 
      await showDialog<BuildContext>(
        context: context,
        builder: (BuildContext dialogContext) {
          // Mostrar el widget en un diálogo invisible
          return Opacity(
            opacity: 0.0,
            child: renderObject,
          );
        }
      ) ?? context;
    
    // Esperar a que termine el frame actual y el siguiente para asegurar renderizado
    await Future.delayed(Duration(milliseconds: 500));
    
    try {
      // Ahora capturar la imagen
      final Uint8List? imageBytes = await PrinterHelper.captureWidgetAsImage(_printKey);
      return imageBytes;
    } catch (e) {
      print('❌ Error capturando factura: $e');
      return null;
    } finally {
      setState(() => _isRendering = false);
      // Cerrar el diálogo si sigue abierto
      if (Navigator.canPop(offScreenContext)) {
        Navigator.pop(offScreenContext);
      }
    }
  }

  // MODIFICACIÓN DE LA FUNCIÓN _confirmSale() en sale_summary_screen.dart
// Reemplaza completamente la función existente con esta versión

Future<void> _confirmSale() async {
  // Mostrar indicador de progreso
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text("Procesando venta..."),
          ],
        ),
      );
    },
  );
  
  try {
    // Verificar stock suficiente
    final insufficient = _products.entries.where((e) => e.key.quantity < e.value);
    if (insufficient.isNotEmpty) {
      final names = insufficient.map((e) => e.key.name).join(', ');
      Navigator.pop(context); // Cerrar diálogo de progreso
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Stock insuficiente para: $names')),
      );
      return;
    }

    // Verificar crédito si es venta a crédito
    if (widget.isCredit && widget.clientPhone != null) {
      final liveClient = await DBHelper.getClientByPhone(widget.clientPhone!);
      if (liveClient == null || !liveClient.hasCredit || liveClient.creditAvailable < _total) {
        Navigator.pop(context); // Cerrar diálogo de progreso
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Este cliente no tiene crédito suficiente.')),
        );
        return;
      }
      _client = liveClient;
    }

    // Crear la venta en la base de datos
    final sale = Sale(
      date: DateTime.now().toIso8601String(),
      total: _total,
      amountDue: _total,
      clientPhone: widget.clientPhone,
      isCredit: widget.isCredit,
    );
    final saleId = await DBHelper.insertSale(sale);
    _generatedSaleId = saleId;

    // Registrar ítems de la venta
    final items = _products.entries.map((entry) {
      final product = entry.key;
      final qty = entry.value;
      final discount = _discounts[product.id] ?? 0.0;
      final subtotal = (product.price - discount) * qty;
      return SaleItem(
        saleId: saleId,
        productId: product.id!,
        quantity: qty,
        subtotal: subtotal,
        discount: discount,
      );
    }).toList();

    await DBHelper.insertSaleItems(items);

    // Actualizar inventario
    for (var entry in _products.entries) {
      if (entry.key.isRentable != true) {
        await DBHelper().reduceProductStock(entry.key.id!, entry.value);
      }
    }

    // Actualizar crédito del cliente
    if (widget.isCredit && _client != null) {
      await DBHelper.updateClientCredit(
        _client!.phone,
        _client!.credit + _total,
        _client!.creditAvailable - _total,
      );
    }
    
    // Cerrar diálogo de progreso
    Navigator.pop(context);
    
    // Mostrar recibo en un diálogo normal (no para impresión, solo visual)
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Venta Completada', textAlign: TextAlign.center),
        content: SingleChildScrollView(
          child: Container(
            width: double.maxFinite,
            child: _buildReceiptForDisplay(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _printReceiptAsText(); // Imprimir después de cerrar el diálogo
            },
            child: Text('Imprimir'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.popUntil(context, ModalRoute.withName('/'));
            },
            child: Text('Finalizar'),
          ),
        ],
      ),
    );
    
  } catch (e) {
    // Cerrar diálogo de progreso si hay error
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
    print('❌ Error en la venta: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error al procesar la venta: $e')),
    );
  }
}

// NUEVO MÉTODO: Construye un widget visual del recibo (solo para mostrar, no para imprimir)
Widget _buildReceiptForDisplay() {
  final totalDiscount = _products.entries.fold(0.0, (sum, entry) {
    final discount = _discounts[entry.key.id] ?? 0.0;
    return sum + (discount * entry.value);
  });

  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Text('DECOYAMIX', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      Text('calle Atilio Pérez, Cutupú, La Vega'),
      Text('(frente al parque)'),
      Text('829-940-5937'),
      SizedBox(height: 10),
      Text(DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())),
      Text('Factura: #${(_generatedSaleId?.toString().padLeft(5, '0')) ?? "-----"}'),
      Divider(),
      Text('Cliente: ${_client != null ? '${_client!.name} ${_client!.lastName}' : 'Desconocido'}'),
      Text('Tel: ${_client?.phone ?? 'Sin teléfono'}'),
      Divider(),
      Text('PRODUCTOS', style: TextStyle(fontWeight: FontWeight.bold)),
      SizedBox(height: 10),
      ..._products.entries.map((entry) {
        final product = entry.key;
        final qty = entry.value;
        final discount = _discounts[product.id] ?? 0.0;
        final subtotal = ((product.price - discount) * qty);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${product.name} x $qty'),
            if (discount > 0)
              Text('  Descuento: \$${discount.toStringAsFixed(2)} c/u', 
                   style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
            Text('  Subtotal: \$${subtotal.toStringAsFixed(2)}'),
            SizedBox(height: 5),
          ],
        );
      }).toList(),
      Divider(),
      if (totalDiscount > 0)
        Text('Descuento total: \$${totalDiscount.toStringAsFixed(2)}'),
      Text('Total a pagar: \$${_total.toStringAsFixed(2)}', 
           style: TextStyle(fontWeight: FontWeight.bold)),
      Text(widget.isCredit ? 'Tipo de pago: Crédito' : 'Tipo de pago: Contado'),
      Divider(),
      Text('¡Gracias por preferirnos!'),
    ],
  );
}

// NUEVO MÉTODO: Imprime el recibo usando comandos de texto directos
Future<void> _printReceiptAsText() async {
  try {
    // Verificar estado de la impresora
    if (!await PrinterHelper.connectToPrinter()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo conectar a la impresora')),
      );
      Navigator.popUntil(context, ModalRoute.withName('/'));
      return;
    }
    
    // Preparar los items para la impresión
    final List<Map<String, dynamic>> items = _products.entries.map((entry) {
      final product = entry.key;
      final qty = entry.value;
      final discount = _discounts[product.id] ?? 0.0;
      final subtotal = (product.price - discount) * qty;
      
      return {
        'name': product.name,
        'quantity': qty,
        'price': product.price,
        'discount': discount,
        'subtotal': subtotal,
      };
    }).toList();
    
    // Calcular descuento total
    final totalDiscount = _products.entries.fold(0.0, (sum, entry) {
      final discount = _discounts[entry.key.id] ?? 0.0;
      return sum + (discount * entry.value);
    });
    
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
              Text("Imprimiendo factura..."),
            ],
          ),
        );
      },
    );
    
    // Imprimir como texto directo
    await PrinterHelper.printInvoiceText(
      businessName: 'DECOYAMIX',
      address: 'calle Atilio Pérez, Cutupú, La Vega',
      phone: '829-940-5937',
      invoiceNumber: _generatedSaleId?.toString().padLeft(5, '0') ?? "-----",
      date: DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
      clientName: _client != null ? '${_client!.name} ${_client!.lastName}' : 'Desconocido',
      clientPhone: _client?.phone ?? 'Sin teléfono',
      items: items,
      totalDiscount: totalDiscount,
      total: _total,
      isCredit: widget.isCredit,
    );
    
    // Cerrar dialogo de progreso
    Navigator.pop(context);
    
    // Regresar a la pantalla principal
    Navigator.popUntil(context, ModalRoute.withName('/'));
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Factura impresa correctamente')),
    );
  } catch (e) {
    // Cerrar diálogo de progreso si hay error
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
    
    print('❌ Error al imprimir factura como texto: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error al imprimir la factura: $e')),
    );
    
    // Regresar a la pantalla principal incluso si hay error
    Navigator.popUntil(context, ModalRoute.withName('/'));
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Resumen de Venta')),
      body: Column(
        children: [
          if (_client != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cliente: ${_client!.name} ${_client!.lastName}'),
                  if (_client!.hasCredit)
                    Text('Crédito disponible: \$${_client!.creditAvailable.toStringAsFixed(2)}'),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: _products.length,
              itemBuilder: (_, index) {
                final product = _products.keys.elementAt(index);
                final qty = _products[product]!;
                final discount = _discounts[product.id] ?? 0.0;
                final subtotal = (product.price - discount) * qty;
                return ListTile(
                  title: Text(product.name),
                  subtitle: Text('Cantidad: $qty - Subtotal: \$${subtotal.toStringAsFixed(2)}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(onPressed: () => _editDiscount(product), icon: Icon(Icons.percent)),
                      IconButton(onPressed: () => _changeQuantity(product, -1), icon: Icon(Icons.remove)),
                      IconButton(onPressed: () => _changeQuantity(product, 1), icon: Icon(Icons.add)),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total: \$${_total.toStringAsFixed(2)}', style: TextStyle(fontSize: 18)),
                ElevatedButton(
                  onPressed: (_products.isEmpty || _isRendering) ? null : _confirmSale,
                  child: Text('Confirmar Venta'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}