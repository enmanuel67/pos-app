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

  // ✅ estado local para reflejar cambios al anular sin depender de reconstrucción externa
  late bool _isVoided;
  String? _voidedAt;

  @override
  void initState() {
    super.initState();
    _isVoided = widget.sale.isVoided;
    _voidedAt = widget.sale.voidedAt;
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

  // ✅ Construye el widget de factura para mostrar y reimprimir
  Widget _buildReceiptWidget() {
    final totalDiscount = _calculateTotalDiscount();

    final clientName =
        _client != null ? "${_client!.name} ${_client!.lastName}" : "Desconocido";
    final clientPhone = _client?.phone ?? "Sin teléfono";

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
                  if (_isVoided)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        '*** FACTURA ANULADA ***',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  const Text(
                    'DECOYAMIX',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Text('calle Atilio Pérez, Cutupú, La Vega'),
                  const Text('(frente al parque)'),
                  const Text('829-940-5937'),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Fecha: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(widget.sale.date))}',
            ),
            Text('Factura: #${widget.sale.id.toString().padLeft(5, '0')}'),
            if (_isVoided && _voidedAt != null)
              Text(
                'Anulada: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(_voidedAt!))}',
                style: const TextStyle(color: Colors.red),
              ),
            const Divider(),
            Text('Cliente: $clientName'),
            Text('Tel: $clientPhone'),
            const Divider(),
            const Text('Producto        Cant.   Subtotal'),
            const Divider(),

            // Lista de productos
            ..._items.map((item) {
              final product = _productMap[item.productId];
              final nameRaw = product?.name ?? 'Producto';
              final nombre = nameRaw.length > 18 ? '${nameRaw.substring(0, 18)}…' : nameRaw;

              final subtotal = item.subtotal.toStringAsFixed(2);
              final desc = item.discount > 0
                  ? ' (Desc. \$${item.discount.toStringAsFixed(2)})'
                  : '';
              final rentable = (product?.isRentable ?? false) ? ' 🛠' : '';

              return Text('$nombre x${item.quantity}  \$${subtotal}$desc$rentable');
            }),

            const Divider(),
            if (totalDiscount > 0)
              Text('Descuento total: \$${totalDiscount.toStringAsFixed(2)}'),
            Text('Total: \$${widget.sale.total.toStringAsFixed(2)}'),
            Text(widget.sale.isCredit ? 'Tipo: Crédito' : 'Tipo: Contado'),

            // Estado crédito (si aplica)
            if (widget.sale.isCredit) ...[
              const Divider(),
              if (widget.sale.amountDue == 0)
                const Text(
                  '✅ FACTURA PAGADA',
                  style: TextStyle(fontWeight: FontWeight.bold),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🔴 PENDIENTE DE PAGO',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Pagado: \$${(widget.sale.total - widget.sale.amountDue).toStringAsFixed(2)}',
                    ),
                    Text('Pendiente: \$${widget.sale.amountDue.toStringAsFixed(2)}'),
                  ],
                ),
            ],

            const Divider(),
            const Center(child: Text('Gracias por preferirnos')),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ✅ Muestra la vista previa del recibo
  void _showReceiptPreview() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Vista Previa de Factura'),
        content: SingleChildScrollView(
          child: RepaintBoundary(
            key: _receiptKey,
            child: _buildReceiptWidget(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          ElevatedButton(
            onPressed: _printReceipt,
            child: const Text('Imprimir'),
          ),
        ],
      ),
    );
  }

  // ✅ Función para imprimir el recibo usando PrinterHelper
  Future<void> _printReceipt() async {
    try {
      // Mostrar indicador de progreso
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            content: Row(
              children: const [
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
        Navigator.pop(context); // cerrar diálogo de progreso
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo conectar a la impresora')),
        );
        return;
      }

      await _printReceiptAsText();

      Navigator.pop(context); // cerrar diálogo de progreso
      Navigator.pop(context); // cerrar preview

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Factura reimpresa correctamente')),
      );
    } catch (e) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al reimprimir la factura: $e')),
      );
    }
  }

  // ✅ Impresión como texto (más confiable para impresoras térmicas)
  Future<void> _printReceiptAsText() async {
    final totalDiscount = _calculateTotalDiscount();
    final totalPaid = widget.sale.total - widget.sale.amountDue;

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

    String estadoCredito = "";
    if (_isVoided) {
      estadoCredito = "FACTURA ANULADA";
    } else if (widget.sale.isCredit) {
      if (widget.sale.amountDue == 0) {
        estadoCredito = "FACTURA PAGADA";
      } else {
        estadoCredito = "PENDIENTE: \$${widget.sale.amountDue.toStringAsFixed(2)}";
      }
    }

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

      // Reimpresión
      isReprint: true,
      creditStatus: estadoCredito,
      amountPaid: totalPaid,
    );
  }

  Future<void> _confirmVoidSale() async {
    if (_isVoided) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Eliminar factura"),
        content: const Text(
          "Esto ANULARÁ la factura, devolverá los productos al inventario y la sacará de los reportes.\n\n¿Seguro que deseas continuar?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Eliminar"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await DBHelper.voidSaleAndRestock(widget.sale.id!);

      // marcar localmente como anulada (auditoría)
      setState(() {
        _isVoided = true;
        _voidedAt = DateTime.now().toIso8601String();
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Factura anulada correctamente")),
      );

      // vuelve al historial y le avisa que hubo cambio
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error al anular factura: $e")),
      );
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
            if (_isVoided) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.red),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "FACTURA ANULADA",
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (_voidedAt != null)
                      Text(
                        "Anulada: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(_voidedAt!))}",
                        style: const TextStyle(color: Colors.red),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Información del cliente
            if (_client != null) ...[
              Text('Cliente: ${_client!.name} ${_client!.lastName}'),
              Text('Teléfono: ${_client!.phone}'),
            ] else ...[
              const Text('Cliente: Desconocido'),
            ],

            // Información de la venta
            Text(
              'Fecha: ${DateFormat('yyyy-MM-dd').format(DateTime.parse(widget.sale.date))}',
            ),
            Text(
              'Tipo de venta: ${widget.sale.isCredit ? "Crédito" : "Contado"}',
            ),

            // Estado de pago para ventas a crédito
            if (widget.sale.isCredit) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: widget.sale.amountDue == 0
                      ? Colors.green.withOpacity(0.2)
                      : Colors.red.withOpacity(0.2),
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
                        color:
                            widget.sale.amountDue == 0 ? Colors.green : Colors.red,
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
                separatorBuilder: (_, __) => const Divider(),
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
                            style: const TextStyle(color: Colors.red),
                          ),
                      ],
                    ),
                    trailing: Text('\$${item.subtotal.toStringAsFixed(2)}'),
                  );
                },
              ),
            ),

            const Divider(),

            // Totales
            if (totalDiscount > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'Descuento total: \$${totalDiscount.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(bottom: 10, top: 8),
              child: Text(
                'Total final: \$${widget.sale.total.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),

            // Botones (Reimprimir + Eliminar)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _showReceiptPreview,
                    icon: const Icon(Icons.print),
                    label: const Text('Reimprimir'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isVoided ? null : _confirmVoidSale,
                    icon: const Icon(Icons.delete),
                    label: const Text('Eliminar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey,
                      disabledForegroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
