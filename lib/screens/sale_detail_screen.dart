import 'package:flutter/material.dart';
import '../models/sale.dart';
import 'package:pos_app/models/product.dart';
import '../models/sale_item.dart';
import '../models/client.dart';
import '../db/db_helper.dart';
import 'package:intl/intl.dart';
import '../helpers/printer_helper.dart';

class SaleDetailScreen extends StatefulWidget {
  final Sale sale;

  const SaleDetailScreen({super.key, required this.sale});

  @override
  State<SaleDetailScreen> createState() => _SaleDetailScreenState();
}

class _SaleDetailScreenState extends State<SaleDetailScreen> {
  List<SaleItem> _items = [];
  Map<int, Product> _productMap = {};
  Client? _client;
  final GlobalKey _receiptKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    final items = await DBHelper.getSaleItems(widget.sale.id!);
    final allProducts = await DBHelper.getProducts();
    final productMap = {for (var p in allProducts) p.id!: p};

    Client? client;
    if (widget.sale.clientPhone != null) {
      client = await DBHelper.getClientByPhone(widget.sale.clientPhone!);
    }

    setState(() {
      _items = items;
      _productMap = productMap;
      _client = client;
    });
  }

  double _calculateTotalDiscount() {
    return _items.fold(
      0.0,
      (sum, item) => sum + (item.discount * item.quantity),
    );
  }

  // Construye el widget de factura para mostrar y reimprimir
  Widget _buildReceiptWidget() {
    final totalDiscount = _calculateTotalDiscount();
    
    return Material(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  Text(
                    '*** REIMPRESIÓN ***',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'DECOYAMIX',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('calle Atilio Pérez, Cutupú, La Vega'),
                  Text('(frente al parque)'),
                  Text('829-940-5937'),
                ],
              ),
            ),
            SizedBox(height: 10),
            Text('Fecha: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(widget.sale.date))}'),
            Text('Factura: #${widget.sale.id.toString().padLeft(5, '0')}'),
            Divider(),
            Text(
              'Cliente: ${_client != null ? "${_client!.name} ${_client!.lastName}" : "Desconocido"}',
            ),
            Text('Tel: ${_client?.phone ?? "Sin teléfono"}'),
            Divider(),
            // Encabezados de productos con espacio fijo para alineación
            Text('Producto        Cant.   Subtotal'),
            Divider(),
            // Lista de productos
            ..._items.map((item) {
              final product = _productMap[item.productId];
              final nombre = (product?.name.length ?? 0) > 18
                  ? '${product!.name.substring(0, 18)}…'
                  : product?.name ?? 'Producto';
              final subtotal = item.subtotal.toStringAsFixed(2);
              final desc = item.discount > 0
                  ? ' (Desc. \$${item.discount.toStringAsFixed(2)})'
                  : '';
              final rentable = (product?.isRentable ?? false) ? ' 🛠' : '';
              return Text(
                '$nombre x${item.quantity}  \$${subtotal}$desc$rentable',
              );
            }),
            Divider(),
            // Información de descuentos y total
            if (totalDiscount > 0)
              Text('Descuento total: \$${totalDiscount.toStringAsFixed(2)}'),
            Text('Total: \$${widget.sale.total.toStringAsFixed(2)}'),
            Text(widget.sale.isCredit ? 'Tipo: Crédito' : 'Tipo: Contado'),
            
            // Información de estado de pago para ventas a crédito
            // Busca la línea 127 del archivo sale_detail_screen.dart
// El error más probable es que haya una coma extra o una lista mal formada

// Revisa la sección donde describes información de crédito, específicamente esta parte:
// Probablemente está en la función _buildReceiptWidget()

// La versión corregida podría ser así:
if (widget.sale.isCredit) ...[
  Divider(),
  if (widget.sale.amountDue == 0)
    Text('✅ FACTURA PAGADA', style: TextStyle(fontWeight: FontWeight.bold))
  else 
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('🔴 PENDIENTE DE PAGO', style: TextStyle(fontWeight: FontWeight.bold)),
        Text('Pagado: \$${(widget.sale.total - widget.sale.amountDue).toStringAsFixed(2)}'),
        Text('Pendiente: \$${widget.sale.amountDue.toStringAsFixed(2)}'),
      ],
    ),
],

// Asegúrate de que los corchetes estén correctamente balanceados
// El error podría estar en una coma extra después del último elemento de una lista
// O podría faltar una coma entre elementos
            
            Divider(),
            Center(child: Text('Gracias por preferirnos')),
            SizedBox(height: 20), // Espacio adicional para impresión
          ],
        ),
      ),
    );
  }
  
  // Muestra la vista previa del recibo
  void _showReceiptPreview() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Vista Previa de Factura'),
        content: SingleChildScrollView(
          child: RepaintBoundary(
            key: _receiptKey,
            child: _buildReceiptWidget(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cerrar'),
          ),
          ElevatedButton(
            onPressed: _printReceipt,
            child: Text('Imprimir'),
          ),
        ],
      ),
    );
  }
  
  // Función para imprimir el recibo usando PrinterHelper
  Future<void> _printReceipt() async {
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
                Text("Imprimiendo factura..."),
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
      
      // Usar impresión de texto directa (más confiable)
      await _printReceiptAsText();
      
      // Cerrar diálogo de progreso
      Navigator.pop(context);
      
      // Cerrar diálogo de previsualización
      Navigator.pop(context);
      
      // Mostrar mensaje de éxito
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Factura reimpresa correctamente')),
      );
    } catch (e) {
      // Cerrar diálogo de progreso si hay error
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      print('❌ Error al reimprimir factura: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al reimprimir la factura: $e')),
      );
    }
  }

  // Impresión como texto (más confiable para impresoras térmicas)
  Future<void> _printReceiptAsText() async {
    try {
      final totalDiscount = _calculateTotalDiscount();
      final totalPaid = widget.sale.total - widget.sale.amountDue;
      
      // Preparar los items para la impresión
      final List<Map<String, dynamic>> items = _items.map((item) {
        final product = _productMap[item.productId];
        return {
          'name': product?.name ?? 'Producto',
          'quantity': item.quantity,
          'price': item.subtotal / item.quantity,
          'discount': item.discount,
          'subtotal': item.subtotal,
        };
      }).toList();
      
      // Texto para el estado de pago
      String estadoCredito = "";
      if (widget.sale.isCredit) {
        if (widget.sale.amountDue == 0) {
          estadoCredito = "FACTURA PAGADA";
        } else {
          estadoCredito = "PENDIENTE: \$${widget.sale.amountDue.toStringAsFixed(2)}";
        }
      }
      
      // Imprimir el recibo como texto
      await PrinterHelper.printInvoiceText(
        businessName: 'DECOYAMIX',
        address: 'calle Atilio Pérez, Cutupú, La Vega',
        phone: '829-940-5937',
        invoiceNumber: widget.sale.id?.toString().padLeft(5, '0') ?? "-----",
        date: DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(widget.sale.date)),
        clientName: _client != null ? '${_client!.name} ${_client!.lastName}' : 'Desconocido',
        clientPhone: _client?.phone ?? 'Sin teléfono',
        items: items,
        totalDiscount: totalDiscount,
        total: widget.sale.total,
        isCredit: widget.sale.isCredit,
        // Pasar parámetros adicionales para mostrar en la reimpresión
        isReprint: true,
        creditStatus: estadoCredito,
        amountPaid: totalPaid,
      );
    } catch (e) {
      throw Exception('Error al imprimir como texto: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalDiscount = _calculateTotalDiscount();

    return Scaffold(
      appBar: AppBar(title: Text('Factura #${widget.sale.id}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Información del cliente
            if (_client != null) ...[
              Text('Cliente: ${_client!.name} ${_client!.lastName}'),
              Text('Teléfono: ${_client!.phone}'),
            ],
            // Información de la venta
            Text('Fecha: ${DateFormat('yyyy-MM-dd').format(DateTime.parse(widget.sale.date))}'),
            Text(
              'Tipo de venta: ${widget.sale.isCredit ? "Crédito" : "Contado"}',
            ),
            
            // Información de estado de pago para ventas a crédito
            if (widget.sale.isCredit) ...[
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: widget.sale.amountDue == 0 ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.sale.amountDue == 0
                          ? '✅ Factura pagada'
                          : '❗ Pendiente de pago',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: widget.sale.amountDue == 0 ? Colors.green : Colors.red,
                      ),
                    ),
                    Text(
                      '💰 Pagado: \$${(widget.sale.total - widget.sale.amountDue).toStringAsFixed(2)}',
                    ),
                    Text('💳 Deuda: \$${widget.sale.amountDue.toStringAsFixed(2)}'),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 16),
            const Text(
              'Productos:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            
            // Lista de productos
            Expanded(
              child: ListView.separated(
                itemCount: _items.length,
                separatorBuilder: (_, __) => Divider(),
                itemBuilder: (_, index) {
                  final item = _items[index];
                  final product = _productMap[item.productId];
                  return ListTile(
                    title: Text(product?.name ?? 'Producto'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Cantidad: ${item.quantity}'),
                        if (item.discount > 0)
                          Text(
                            'Descuento: \$${item.discount.toStringAsFixed(2)} por unidad',
                            style: TextStyle(color: Colors.red),
                          ),
                      ],
                    ),
                    trailing: Text('\$${item.subtotal.toStringAsFixed(2)}'),
                  );
                },
              ),
            ),
            
            Divider(),
            
            // Información de totales
            if (totalDiscount > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'Descuento total: \$${totalDiscount.toStringAsFixed(2)}',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(bottom: 16, top: 8),
              child: Text(
                'Total final: \$${widget.sale.total.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            
            // Botón de reimpresión
            Center(
              child: ElevatedButton.icon(
                onPressed: _showReceiptPreview,
                icon: Icon(Icons.print),
                label: Text('Reimprimir factura'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}