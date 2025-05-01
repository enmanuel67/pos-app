import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import 'package:pos_app/models/product.dart';
import 'create_product_screen.dart';
import 'package:barcode_widget/barcode_widget.dart';
import '../helpers/printer_helper.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;


class InventoryScreen extends StatefulWidget {
  final String? initialBarcode;

  const InventoryScreen({Key? key, this.initialBarcode}) : super(key: key);

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _costController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final nameController = TextEditingController();
  final barcodeController = TextEditingController();
  final descriptionController = TextEditingController();
  final priceController = TextEditingController();
  final costController = TextEditingController();
  final GlobalKey previewKey = GlobalKey();

  Product? _selectedProduct;
  String? _notFoundBarcode;
  List<Map<String, dynamic>> _inventoryList = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialBarcode != null) {
      _barcodeController.text = widget.initialBarcode!;
      _searchProductByBarcode();
    }
  }

  void _searchProductByBarcode() async {
    final barcode = _barcodeController.text.trim();
    if (barcode.isEmpty) return;

    final product = await DBHelper.getProductByBarcode(barcode);
    if (product == null) {
      setState(() {
        _selectedProduct = null;
        _notFoundBarcode = barcode;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Este producto no existe')));
    } else {
      setState(() {
        _selectedProduct = product;
        _notFoundBarcode = null;
        _costController.text = product.cost.toString();
        _priceController.text = product.price.toString();
      });
    }
  }

  void _addToInventoryList() {
    final qty = int.tryParse(_quantityController.text) ?? 0;
    final cost = double.tryParse(_costController.text) ?? 0.0;
    final price = double.tryParse(_priceController.text) ?? 0.0;

    if (_selectedProduct == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complete los datos correctamente')),
      );
      return;
    }

    setState(() {
      _inventoryList.add({
        'product': _selectedProduct!,
        'quantity': qty,
        'cost': cost,
        'price': price,
      });

      _barcodeController.clear();
      _quantityController.clear();
      _costController.clear();
      _priceController.clear();
      _selectedProduct = null;
    });
  }

  Future<void> _confirmInventory() async {
    for (var item in _inventoryList) {
      final product = item['product'] as Product;
      final quantity = item['quantity'] as int;
      final cost = item['cost'] as double;
      final price = item['price'] as double;

      await DBHelper.updateProductStock(product.id!, quantity, cost);

      // ✅ Actualizar precio si cambió
      if (price != product.price) {
        final updatedProduct = product.copyWith(price: price);
        await DBHelper.updateProduct(updatedProduct);
      }
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Inventario actualizado')));

    setState(() {
      _inventoryList.clear();
    });
  }

  // Optimización de la función de impresión de stickers
// Reemplaza el código actual de impresión por esta versión optimizada

// Función optimizada de impresión de stickers para inventory_screen.dart
// Esta función debe ir DENTRO de la clase _InventoryScreenState

Future<void> _printSticker() async {
  if (_selectedProduct == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Primero selecciona un producto.')),
    );
    return;
  }

  final truncatedName =
      (_selectedProduct!.name.length > 20)
          ? '${_selectedProduct!.name.substring(0, 20)}…'
          : _selectedProduct!.name;

  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Vista previa del Sticker'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RepaintBoundary(
            key: previewKey,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(),
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BarcodeWidget(
                    barcode: Barcode.code128(),
                    data: _selectedProduct!.barcode.isEmpty
                        ? '0'
                        : _selectedProduct!.barcode,
                    width: 110,
                    height: 35,
                    drawText: false,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    truncatedName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '\$${_selectedProduct!.price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 20), // espacio para terminar el sticker
                ],
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
        ElevatedButton(
          onPressed: () async {
            final controller = TextEditingController(text: '1');
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('¿Cuántos stickers deseas imprimir?'),
                content: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Cantidad'),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancelar'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Imprimir'),
                  ),
                ],
              ),
            );

            if (confirmed == true) {
              final cantidad = int.tryParse(controller.text.trim()) ?? 1;

              if (cantidad > 50) {
                final seguro = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Confirmación'),
                    content: Text('¿Deseas imprimir $cantidad stickers?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('No'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Sí'),
                      ),
                    ],
                  ),
                );

                if (seguro != true) return;
              }

              _printMultipleStickers(cantidad);
            }
          },
          child: const Text('Imprimir Sticker'),
        ),
      ],
    ),
  );
}

// Función optimizada para imprimir múltiples stickers
Future<void> _printMultipleStickers(int cantidad) async {
  try {
    // Mostrar indicador de progreso
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("Preparando impresión..."),
            ],
          ),
        );
      },
    );
    
    // 1. Verificar la conexión a la impresora primero
    final connected = await PrinterHelper.connectToPrinter();
    if (!connected) {
      Navigator.pop(context); // Cerrar diálogo de progreso
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo conectar a la impresora')),
      );
      return;
    }
    
    // 2. Capturar la imagen una sola vez (no en cada iteración)
    final boundary = previewKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    
    if (byteData == null) {
      Navigator.pop(context); // Cerrar diálogo de progreso
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo capturar la imagen del sticker')),
      );
      return;
    }
    
    final imageBytes = byteData.buffer.asUint8List();
    
    // 3. Redimensionar una sola vez
    final resizedImage = await PrinterHelper.resizeImageToSize(
      originalBytes: imageBytes,
      targetWidth: 350,
      targetHeight: 200,
    );
    
    // Actualizar mensaje de progreso
    Navigator.pop(context); // Cerrar diálogo inicial
    
    // Mostrar nuevo diálogo con progreso
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text("Imprimiendo stickers: 0/$cantidad"),
                  SizedBox(height: 8),
                  LinearProgressIndicator(value: 0),
                ],
              ),
            );
          }
        );
      },
    );
    
    // 4. Usar un mejor esquema de impresión por lotes
    const loteSize = 5; // Número de stickers a imprimir en cada lote
    int stickersImpresos = 0;
    
    for (int i = 0; i < cantidad; i += loteSize) {
      // Determinar cuántos stickers imprimir en este lote
      final stickersEnLote = (i + loteSize <= cantidad) ? loteSize : (cantidad - i);
      
      // Imprimir el lote actual
      for (int j = 0; j < stickersEnLote; j++) {
        await PrinterHelper.printImage(resizedImage);
        
        // Solo agregar líneas en blanco entre stickers, no después del último
        if (j < stickersEnLote - 1) {
          await PrinterHelper.printNewLines(2);
        }
        
        // Actualizar contador
        stickersImpresos++;
        
        // Actualizar el diálogo (solo cada 5 stickers para no sobrecargar la UI)
        if (stickersImpresos % 5 == 0 || stickersImpresos == cantidad) {
          // Cerrar y volver a abrir el diálogo con valores actualizados
          Navigator.pop(context);
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return AlertDialog(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text("Imprimiendo stickers: $stickersImpresos/$cantidad"),
                    SizedBox(height: 8),
                    LinearProgressIndicator(value: stickersImpresos / cantidad),
                  ],
                ),
              );
            },
          );
        }
      }
      
      // Hacer una pausa entre lotes para evitar sobrecarga de la impresora
      if (i + loteSize < cantidad) {
        await Future.delayed(const Duration(milliseconds: 1000));
      }
    }
    
    // 5. Finalizar con líneas adicionales
    await PrinterHelper.printNewLines(4);
    
    // Cerrar diálogo de progreso
    Navigator.pop(context);
    
    // Mostrar mensaje de éxito
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Se imprimieron $cantidad stickers correctamente')),
    );
    
    // Cerrar el diálogo de vista previa
    Navigator.pop(context);
    
  } catch (e) {
    // Asegurarse de cerrar cualquier diálogo abierto
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
    
    print('❌ Error al imprimir stickers: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error al imprimir: $e')),
    );
  }
}

// Esta versión optimizada se llama directamente desde el botón "Imprimir" de la vista previa
// Reemplaza la sección del código de impresión actual con esta llamada:

/*
ElevatedButton(
  onPressed: () async {
    final controller = TextEditingController(text: '1');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Cuántos stickers deseas imprimir?'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Cantidad'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Imprimir'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final cantidad = int.tryParse(controller.text.trim()) ?? 1;

      if (cantidad > 50) {
        final seguro = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Confirmación'),
            content: Text('¿Deseas imprimir $cantidad stickers?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Sí'),
              ),
            ],
          ),
        );

        if (seguro != true) return;
      }

      // Llamar a la función optimizada
      _printStickers(cantidad);
    }
  },
  child: const Text('Imprimir Sticker'),
),
*/

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ingreso a Inventario')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _barcodeController,
                      decoration: InputDecoration(
                        labelText: 'Código de barra',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: _searchProductByBarcode,
                        ),
                      ),
                      onSubmitted: (_) => _searchProductByBarcode(),
                    ),
                    const SizedBox(height: 10),

                    if (_selectedProduct != null) ...[
                      Text('Nombre: ${_selectedProduct!.name}'),
                      Text('Descripción: ${_selectedProduct!.description}'),
                      Text('Precio actual: \$${_selectedProduct!.price}'),
                      Text('Cantidad actual: ${_selectedProduct!.quantity}'),
                      const SizedBox(height: 10),

                      TextField(
                        controller: _costController,
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Costo unitario',
                        ),
                      ),
                      TextField(
                        controller: _priceController,
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Precio de venta',
                        ),
                      ),
                      TextField(
                        controller: _quantityController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Cantidad a agregar',
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _addToInventoryList,
                              child: const Text('Agregar a la lista'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _printSticker,
                              child: const Text('Imprimir Sticker'),
                            ),
                          ),
                        ],
                      ),
                      const Divider(),
                    ],

                    if (_notFoundBarcode != null) ...[
                      const SizedBox(height: 10),
                      Center(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.add_box_outlined),
                          label: const Text('Crear nuevo producto'),
                          onPressed: () async {
                            final created = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) => CreateProductScreen(
                                      initialBarcode: _notFoundBarcode!,
                                    ),
                              ),
                            );

                            if (created == true) {
                              _searchProductByBarcode();
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Divider(),
                    ],

                    const Text(
                      'Productos por agregar:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 300, // Puedes ajustar esta altura si lo necesitas
                      child: ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _inventoryList.length,
                        itemBuilder: (_, index) {
                          final item = _inventoryList[index];
                          final product = item['product'] as Product;
                          final quantity = item['quantity'];
                          final cost = item['cost'];
                          final price = item['price'];
                          final total = (cost * quantity).toStringAsFixed(2);

                          return ListTile(
                            title: Text(product.name),
                            subtitle: Text(
                              'Cantidad: $quantity | Costo: \$${cost.toStringAsFixed(2)} | Precio: \$${price.toStringAsFixed(2)}',
                            ),
                            trailing: Text('Total: \$${total}'),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 10),
                    if (_inventoryList.isNotEmpty)
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: _confirmInventory,
                          icon: const Icon(Icons.inventory),
                          label: const Text('Confirmar ingreso a inventario'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
