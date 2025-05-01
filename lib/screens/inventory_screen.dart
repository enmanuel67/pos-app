import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart'
    hide Barcode; // Ocultar Barcode de mobile_scanner
import '../db/db_helper.dart';
import 'package:pos_app/models/product.dart';
import 'create_product_screen.dart';
import 'package:barcode_widget/barcode_widget.dart';
import '../helpers/printer_helper.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'dart:async';

class InventoryScreen extends StatefulWidget {
  final String? initialBarcode;

  const InventoryScreen({Key? key, this.initialBarcode}) : super(key: key);

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _costController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final GlobalKey previewKey = GlobalKey();

  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];
  Product? _selectedProduct;
  String? _notFoundBarcode;
  List<Map<String, dynamic>> _inventoryList = [];
  bool _isScanning = false;
  bool _isSearchingByName = false;
  MobileScannerController? _scannerController;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    if (widget.initialBarcode != null) {
      _barcodeController.text = widget.initialBarcode!;
      _searchProductByBarcode();
    }
    _loadAllProducts();

    // Agregar listener para búsqueda por nombre
    _searchController.addListener(_onSearchTextChanged);
  }

  @override
  void dispose() {
    _disposeScanner();
    _barcodeController.dispose();
    _searchController.dispose();
    _quantityController.dispose();
    _costController.dispose();
    _priceController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _loadAllProducts() async {
    final products = await DBHelper.getProducts();
    if (mounted) {
      setState(() {
        _allProducts = products;
      });
    }
  }

  void _onSearchTextChanged() {
    // Implementar debounce para no buscar con cada tecla presionada
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;

      if (_searchController.text.isEmpty) {
        setState(() {
          _filteredProducts = [];
          _isSearchingByName = false;
        });
        return;
      }

      setState(() {
        _isSearchingByName = true;
        _filteredProducts =
            _allProducts
                .where(
                  (p) => p.name.toLowerCase().contains(
                    _searchController.text.toLowerCase(),
                  ),
                )
                .toList();
      });
    });
  }

  void _disposeScanner() {
    _scannerController?.dispose();
    _scannerController = null;
  }

  void _toggleScanner() {
    setState(() {
      _isScanning = !_isScanning;
      if (_isScanning) {
        _initializeScanner();
      } else {
        _disposeScanner();
      }
    });
  }

  void _initializeScanner() {
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      formats: const [BarcodeFormat.all],
      autoStart: true,
    );
  }

  void _selectProductFromSearch(Product product) {
    setState(() {
      _selectedProduct = product;
      _notFoundBarcode = null;
      _costController.text = product.cost.toString();
      _priceController.text = product.price.toString();
      _barcodeController.text = product.barcode;
      _isSearchingByName = false;
      _searchController.clear();
    });
  }

  void _searchProductByBarcode() async {
    final barcode = _barcodeController.text.trim();
    if (barcode.isEmpty) return;

    final product = await DBHelper.getProductByBarcode(barcode);
    if (!mounted) return;

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

      // Actualizar precio si cambió
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

    // Recargar productos después de actualizar
    _loadAllProducts();
  }

  // Función mejorada para generar stickers escaneables
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
      builder:
          (_) => AlertDialog(
            title: const Text('Vista previa del Sticker'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RepaintBoundary(
                  key: previewKey,
                  child: Container(
                    width: 450,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      border: Border.all(),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Código de barras primero
                        Container(
                          color: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 0,
                            vertical: 10,
                          ),
                          child: BarcodeWidget(
                            barcode: Barcode.code128(),
                            data:
                                _selectedProduct!.barcode.isEmpty
                                    ? '0'
                                    : _selectedProduct!.barcode,
                            width: 500,
                            height: 120,
                            drawText: true,
                            style: const TextStyle(fontSize: 12),
                            margin: const EdgeInsets.all(10),
                            padding: const EdgeInsets.all(0),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Nombre del producto segundo
                        Text(
                          truncatedName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 12),

                        // Precio tercero
                        Text(
                          '\$${_selectedProduct!.price.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
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
                onPressed: () => _showPrintDialog(),
                child: const Text('Imprimir Sticker'),
              ),
            ],
          ),
    );
  }

  void _showPrintDialog() async {
    final controller = TextEditingController(text: '1');
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
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
          builder:
              (_) => AlertDialog(
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
  }

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
              children: const [
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
          const SnackBar(content: Text('No se pudo conectar a la impresora')),
        );
        return;
      }

      // 2. Capturar la imagen una sola vez (no en cada iteración)
      final boundary =
          previewKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3); // Mayor resolución
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        Navigator.pop(context); // Cerrar diálogo de progreso
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo capturar la imagen del sticker'),
          ),
        );
        return;
      }

      final imageBytes = byteData.buffer.asUint8List();

      // 3. Redimensionar una sola vez
      final resizedImage = await PrinterHelper.resizeImageToSize(
        originalBytes: imageBytes,
        targetWidth: 380, // Mayor ancho para mejor calidad
        targetHeight: 220, // Mayor altura para mejor calidad
      );

      // Actualizar mensaje de progreso
      if (mounted) {
        Navigator.pop(context); // Cerrar diálogo inicial

        // Mostrar nuevo diálogo con progreso
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text("Imprimiendo stickers: 0/$cantidad"),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: 0),
                ],
              ),
            );
          },
        );
      }

      // 4. Usar un mejor esquema de impresión por lotes
      const loteSize = 5; // Número de stickers a imprimir en cada lote
      int stickersImpresos = 0;

      for (int i = 0; i < cantidad; i += loteSize) {
        // Determinar cuántos stickers imprimir en este lote
        final stickersEnLote =
            (i + loteSize <= cantidad) ? loteSize : (cantidad - i);

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
          if ((stickersImpresos % 5 == 0 || stickersImpresos == cantidad) &&
              mounted) {
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
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text("Imprimiendo stickers: $stickersImpresos/$cantidad"),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: stickersImpresos / cantidad,
                      ),
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
      if (mounted) {
        Navigator.pop(context);

        // Mostrar mensaje de éxito
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Se imprimieron $cantidad stickers correctamente'),
          ),
        );

        // Cerrar el diálogo de vista previa
        Navigator.pop(context);
      }
    } catch (e) {
      // Asegurarse de cerrar cualquier diálogo abierto
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      print('❌ Error al imprimir stickers: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al imprimir: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ingreso a Inventario'),
        actions: [
          IconButton(
            icon: Icon(
              _isScanning
                  ? Icons.qr_code_scanner_rounded
                  : Icons.qr_code_scanner,
            ),
            color: _isScanning ? Colors.blue : null,
            onPressed: _toggleScanner,
            tooltip: 'Escanear código de barras',
          ),
        ],
      ),
      body: SafeArea(
        child: GestureDetector(
          onTap: () {
            // Cerrar teclado al tocar fuera de un campo
            FocusScope.of(context).unfocus();
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Scanner de código de barras integrado
                if (_isScanning)
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: MobileScanner(
                        controller: _scannerController!,
                        onDetect: (BarcodeCapture capture) {
                          if (capture.barcodes.isNotEmpty) {
                            final barcode = capture.barcodes.first;
                            final code = barcode.rawValue;

                            if (code != null && code.isNotEmpty) {
                              setState(() {
                                _barcodeController.text = code;
                                _isScanning = false;
                                _disposeScanner();
                              });
                              // Buscar el producto automáticamente
                              _searchProductByBarcode();
                            }
                          }
                        },
                        overlay: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.blue, width: 2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),

                if (_isScanning)
                  const Padding(
                    padding: EdgeInsets.only(top: 8, bottom: 16),
                    child: Center(
                      child: Text(
                        'Centre el código de barras en el recuadro',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),

                // Campo de búsqueda por código de barras
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _barcodeController,
                        decoration: InputDecoration(
                          labelText: 'Código de barra',
                          prefixIcon: const Icon(Icons.qr_code),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.search),
                            onPressed: _searchProductByBarcode,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onSubmitted: (_) => _searchProductByBarcode(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.qr_code_scanner),
                      onPressed: _toggleScanner,
                      tooltip: 'Escanear',
                      color: Colors.blue,
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Campo de búsqueda por nombre
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Buscar producto por nombre',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),

                // Mostrar resultados de búsqueda por nombre
                if (_isSearchingByName && _filteredProducts.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filteredProducts.length,
                      itemBuilder: (context, index) {
                        final product = _filteredProducts[index];
                        return ListTile(
                          title: Text(product.name),
                          subtitle: Text(
                            'Código: ${product.barcode} | Precio: \$${product.price.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          onTap: () {
                            _selectProductFromSearch(product);
                          },
                        );
                      },
                    ),
                  ),

                const SizedBox(height: 16),

                if (_selectedProduct != null) ...[
                  // Información del producto seleccionado
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nombre: ${_selectedProduct!.name}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text('Descripción: ${_selectedProduct!.description}'),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Precio actual: \$${_selectedProduct!.price}',
                                style: const TextStyle(color: Colors.blue),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'Cantidad actual: ${_selectedProduct!.quantity}',
                                style: const TextStyle(color: Colors.green),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Campos para actualizar el producto
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _costController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Costo unitario',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _priceController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Precio de venta',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  TextField(
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Cantidad a agregar',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _addToInventoryList,
                          icon: const Icon(Icons.add_shopping_cart),
                          label: const Text('Agregar a la lista'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _printSticker,
                          icon: const Icon(Icons.print),
                          label: const Text('Imprimir Sticker'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                ],

                if (_notFoundBarcode != null) ...[
                  Center(
                    child: Column(
                      children: [
                        const Text(
                          'Producto no encontrado',
                          style: TextStyle(fontSize: 16, color: Colors.red),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add_box_outlined),
                          label: const Text('Crear nuevo producto'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
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
                              _loadAllProducts();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 16),
                ],

                // Lista de productos a agregar
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Productos por agregar:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),

                if (_inventoryList.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'No hay productos agregados',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _inventoryList.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final item = _inventoryList[index];
                      final product = item['product'] as Product;
                      final quantity = item['quantity'];
                      final cost = item['cost'];
                      final price = item['price'];
                      final total = (cost * quantity).toStringAsFixed(2);

                      return ListTile(
                        title: Text(
                          product.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Cantidad: $quantity | Costo: \$${cost.toStringAsFixed(2)} | Precio: \$${price.toStringAsFixed(2)}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Total: \$${total}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  _inventoryList.removeAt(index);
                                });
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                const SizedBox(height: 16),

                if (_inventoryList.isNotEmpty)
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: _confirmInventory,
                      icon: const Icon(Icons.inventory),
                      label: const Text('Confirmar ingreso a inventario'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
