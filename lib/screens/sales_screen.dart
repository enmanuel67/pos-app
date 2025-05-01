import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pos_app/models/product.dart';
import '../db/db_helper.dart';
import 'sale_summary_screen.dart';
import 'dart:async'; // Importar para usar Timer

class SalesScreen extends StatefulWidget {
  final String? clientPhone;

  const SalesScreen({Key? key, this.clientPhone}) : super(key: key);

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  final Map<Product, int> _cart = {};
  final TextEditingController _searchController = TextEditingController();
  double _total = 0.0;
  MobileScannerController? _scannerController;
  bool _isScanning = false;
  bool _isCooldown = false;
  String? _scanMessage;
  Timer? _messageTimer;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _searchController.addListener(_filterProducts);
  }

  void _loadProducts() async {
    final products = await DBHelper.getProducts();
    setState(() {
      _products = products;
      _filteredProducts = products;
    });
  }

  void _filterProducts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredProducts =
          _products
              .where(
                (p) =>
                    p.name.toLowerCase().contains(query) ||
                    p.barcode.toLowerCase().contains(query),
              )
              .toList();
    });
  }

  void _addToCart(Product product) {
    setState(() {
      _cart[product] = (_cart[product] ?? 0) + 1;
      _calculateTotal();

      // Mostrar mensaje temporal
      _showTemporaryMessage("${product.name} agregado al carrito");
    });
  }

  void _removeFromCart(Product product) {
    setState(() {
      if (_cart.containsKey(product) && _cart[product]! > 1) {
        _cart[product] = _cart[product]! - 1;
      } else {
        _cart.remove(product);
      }
      _calculateTotal();
    });
  }

  void _calculateTotal() {
    _total = 0.0;
    _cart.forEach((product, qty) {
      _total += product.price * qty;
    });
  }

  void _showTemporaryMessage(String message) {
    setState(() {
      _scanMessage = message;
    });

    _messageTimer?.cancel();
    _messageTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _scanMessage = null;
        });
      }
    });
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
      // Configuraciones que pueden mejorar la detección
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      formats: const [
        BarcodeFormat.all,
      ], // Asegurarse que todos los formatos estén habilitados
      autoStart: true,
    );
  }

  void _disposeScanner() {
    _scannerController?.dispose();
    _scannerController = null;
  }

  void _handleScannedBarcode(String barcode) {
    // Verificar cooldown para evitar escaneos duplicados rápidos
    if (_isCooldown) return;

    // Activar cooldown
    setState(() {
      _isCooldown = true;
    });

    // Buscar el producto en la base de datos
    final matched = _products.firstWhere(
      (p) => p.barcode == barcode,
      orElse:
          () => Product(
            id: 0,
            name: '',
            barcode: '',
            description: '',
            price: 0.0,
            quantity: 0,
            cost: 0.0,
            supplierId: 0,
            createdAt: DateTime.now().toIso8601String(),
            businessType: 'A',
            isRentable: false,
          ),
    );

    // Debug: Imprimir información
    debugPrint('Código escaneado: $barcode');
    debugPrint('Producto encontrado: ${matched.name}');

    if (matched.name.isNotEmpty) {
      _addToCart(matched);
      _showTemporaryMessage("Producto agregado: ${matched.name}");
    } else {
      _showTemporaryMessage("Producto no encontrado: $barcode");
    }

    // Desactivar cooldown después de un tiempo
    Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _isCooldown = false;
        });
      }
    });
  }

  void _selectPaymentMethod() {
    if (_cart.isEmpty) return;

    if (_isScanning) {
      _toggleScanner();
    }

    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Tipo de venta'),
            content: const Text('¿Cómo desea registrar esta venta?'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _goToSummary(isCredit: false);
                },
                child: const Text('Contado'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _goToSummary(isCredit: true);
                },
                child: const Text('Crédito'),
              ),
            ],
          ),
    );
  }

  void _goToSummary({required bool isCredit}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => SaleSummaryScreen(
              selectedProducts: Map<Product, int>.from(_cart),
              clientPhone: widget.clientPhone,
              isCredit: isCredit,
            ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _disposeScanner();
    _messageTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleccionar productos'),
        actions: [
          IconButton(
            icon: Icon(
              _isScanning
                  ? Icons.qr_code_scanner_rounded
                  : Icons.qr_code_scanner,
            ),
            color: _isScanning ? Colors.blue : null,
            onPressed: _toggleScanner,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Buscar producto por nombre o código...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          if (_isScanning)
            SizedBox(
              height: 200,
              child: ClipRect(
                child: MobileScanner(
                  controller: _scannerController!,
                  onDetect: (BarcodeCapture capture) {
                    if (capture.barcodes.isNotEmpty) {
                      final barcode = capture.barcodes.first;
                      final code = barcode.rawValue;

                      // Verificar que el código es válido
                      if (code != null && code.isNotEmpty) {
                        _handleScannedBarcode(code);
                      }
                    }
                  },
                  // Overlay para mejorar experiencia visual
                  overlay: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blue, width: 2),
                    ),
                  ),
                ),
              ),
            ),
          if (_scanMessage != null)
            Container(
              color: Colors.green.shade100,
              padding: const EdgeInsets.all(8),
              width: double.infinity,
              child: Text(
                _scanMessage!,
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: _filteredProducts.length,
              itemBuilder: (context, index) {
                final product = _filteredProducts[index];
                final qty = _cart[product] ?? 0;
                return ListTile(
                  title: Text(product.name),
                  subtitle: Text(
                    '\$${product.price.toStringAsFixed(2)} - Código: ${product.barcode}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (qty > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'x$qty',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      IconButton(
                        icon: const Icon(Icons.remove),
                        onPressed:
                            qty > 0 ? () => _removeFromCart(product) : null,
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () => _addToCart(product),
                      ),
                    ],
                  ),
                  onTap: () => _addToCart(product),
                );
              },
            ),
          ),
          Container(
            color: Colors.grey.shade200,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (_cart.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Carrito: ${_cart.entries.fold<int>(0, (sum, entry) => sum + entry.value)} productos',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total: \$${_total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _cart.isEmpty ? null : _selectPaymentMethod,
                      icon: const Icon(Icons.shopping_cart_checkout),
                      label: const Text('Confirmar venta'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
