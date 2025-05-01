import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';

class PrinterHelper {
  static final BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;
  static bool _isConnecting = false;

  static Future<bool> connectToPrinter() async {
    if (_isConnecting) return false;
    
    try {
      _isConnecting = true;
      final isConnected = await bluetooth.isConnected ?? false;
      
      if (!isConnected) {
        final devices = await bluetooth.getBondedDevices();
        if (devices.isEmpty) {
          print('⚠️ No hay impresoras Bluetooth vinculadas.');
          return false;
        }
        
        print('🔄 Conectando a la impresora: ${devices.first.name}');
        await bluetooth.connect(devices.first);
        
        // Tiempo para establecer la conexión
        await Future.delayed(const Duration(seconds: 2));
        
        // Verificar que se conectó correctamente
        final connected = await bluetooth.isConnected ?? false;
        if (!connected) {
          print('❌ No se pudo conectar a la impresora.');
          return false;
        }
        
        print('✅ Conectado a la impresora: ${devices.first.name}');
      }
      
      return true;
    } catch (e) {
      print('❌ Error al conectar con la impresora: $e');
      return false;
    } finally {
      _isConnecting = false;
    }
  }

  static Future<void> printSticker({
    required String name,
    required double price,
    required String barcodeData,
    required GlobalKey previewKey,
  }) async {
    try {
      final connected = await connectToPrinter();
      if (!connected) {
        print('❌ No hay conexión a impresora.');
        return;
      }
      
      final imageBytes = await captureWidgetAsImage(previewKey);
      if (imageBytes != null) {
        await printImage(imageBytes);
      } else {
        print('❌ No se pudo capturar la imagen del sticker.');
      }
    } catch (e) {
      print('❌ Error al imprimir sticker: $e');
    }
  }

  static Future<void> printMultipleStickers({
    required int cantidad,
    required GlobalKey previewKey,
  }) async {
    try {
      final connected = await connectToPrinter();
      if (!connected) {
        print('❌ No hay conexión a impresora.');
        return;
      }
      
      final imageBytes = await captureWidgetAsImage(previewKey);
      if (imageBytes == null) {
        print('❌ No se pudo capturar la imagen de los stickers.');
        return;
      }

      for (int i = 0; i < cantidad; i++) {
        await printImage(imageBytes);
        await printNewLines(4);
        await Future.delayed(const Duration(milliseconds: 800));
      }
    } catch (e) {
      print('❌ Error al imprimir múltiples stickers: $e');
    }
  }

  static Future<void> printImage(Uint8List imageBytes) async {
    try {
      final isConnected = await bluetooth.isConnected ?? false;
      if (!isConnected) {
        final connected = await connectToPrinter();
        if (!connected) return;
      }
      
      print('🖨️ Imprimiendo imagen de ${imageBytes.length} bytes...');
      await bluetooth.printImageBytes(imageBytes);
      print('✅ Imagen enviada a la impresora.');
    } catch (e) {
      print('❌ Error al imprimir imagen: $e');
    }
  }

  static Future<void> printNewLines(int count) async {
    try {
      for (int i = 0; i < count; i++) {
        await bluetooth.printCustom('', 1, 1);
      }
    } catch (e) {
      print('❌ Error al imprimir líneas nuevas: $e');
    }
  }

  static Future<Uint8List?> captureWidgetAsImage(GlobalKey key) async {
    try {
      // Dar tiempo a Flutter para renderizar el widget
      await Future.delayed(Duration(milliseconds: 300));
      
      final renderObject = key.currentContext?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) {
        print('❌ No se pudo obtener un RenderRepaintBoundary válido.');
        print('🔍 Tipo de objeto obtenido: ${renderObject.runtimeType}');
        return null;
      }

      final boundary = renderObject;
      
      // Esperar a que termine cualquier operación de renderizado pendiente
      await Future.delayed(Duration(milliseconds: 200));
      
      // Capturar a mayor resolución para impresoras térmicas (normalmente 203 DPI)
      final image = await boundary.toImage(pixelRatio: 2.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        print('❌ No se pudo convertir a ByteData.');
        return null;
      }

      print('✅ Imagen capturada correctamente: ${image.width}x${image.height}');
      return byteData.buffer.asUint8List();
    } catch (e) {
      print('❌ Error al capturar widget: $e');
      return null;
    }
  }

  static Future<Uint8List> resizeImageToSize({
    required Uint8List originalBytes,
    required int targetWidth,
    required int targetHeight,
  }) async {
    try {
      final codec = await ui.instantiateImageCodec(
        originalBytes,
        targetWidth: targetWidth,
        targetHeight: targetHeight,
      );
      final frame = await codec.getNextFrame();
      final byteData = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      return byteData!.buffer.asUint8List();
    } catch (e) {
      print('❌ Error al redimensionar imagen: $e');
      rethrow;
    }
  }

  static Future<void> disconnect() async {
    try {
      final isConnected = await bluetooth.isConnected ?? false;
      if (isConnected) {
        await bluetooth.disconnect();
        print('✅ Desconectado de la impresora.');
      }
    } catch (e) {
      print('❌ Error al desconectar: $e');
    }
  }
  
  // Método para impresión de texto directo (más confiable para facturas)
  static Future<void> printInvoiceText({
    required String businessName,
    required String address,
    required String phone,
    required String invoiceNumber,
    required String date,
    required String clientName,
    required String clientPhone,
    required List<Map<String, dynamic>> items,
    required double totalDiscount,
    required double total,
    required bool isCredit,
    // Parámetros adicionales para reimpresiones
    bool isReprint = false,
    String creditStatus = "",
    double amountPaid = 0.0,
  }) async {
    try {
      final connected = await connectToPrinter();
      if (!connected) return;
      
      // Encabezado
      if (isReprint) {
        await bluetooth.printCustom("*** REIMPRESION ***", 1, 1);
      }
      
      await bluetooth.printCustom(businessName, 1, 1); // Centered, normal size
      await bluetooth.printCustom(address, 0, 1); 
      await bluetooth.printCustom(phone, 0, 1);
      await bluetooth.printNewLine();
      
      // Detalles de factura
      await bluetooth.printCustom("FACTURA #$invoiceNumber", 1, 1);
      await bluetooth.printCustom("Fecha: $date", 0, 1);
      await bluetooth.printCustom("--------------------------------", 0, 1);
      
      // Cliente
      await bluetooth.printCustom("Cliente: $clientName", 0, 0); // Aligned left
      await bluetooth.printCustom("Tel: $clientPhone", 0, 0);
      await bluetooth.printCustom("--------------------------------", 0, 1);
      
      // Encabezados de productos
      await bluetooth.printCustom("PRODUCTO  CANT  PRECIO  SUBTOTAL", 0, 0);
      await bluetooth.printCustom("--------------------------------", 0, 1);
      
      // Productos
      for (final item in items) {
        String line = "${item['name'].toString().substring(0, 
            item['name'].toString().length > 10 ? 10 : item['name'].toString().length)}";
        line = line.padRight(12);
        
        line += "${item['quantity']}".padRight(6);
        line += "\$${item['price'].toStringAsFixed(2)}".padRight(8);
        line += "\$${item['subtotal'].toStringAsFixed(2)}";
        
        await bluetooth.printCustom(line, 0, 0);
        
        // Si hay descuento, mostrar
        if (item['discount'] > 0) {
          await bluetooth.printCustom("  Desc: \$${item['discount'].toStringAsFixed(2)}", 0, 0);
        }
      }
      
      await bluetooth.printCustom("--------------------------------", 0, 1);
      
      // Totales
      if (totalDiscount > 0) {
        await bluetooth.printCustom("Descuento Total: \$${totalDiscount.toStringAsFixed(2)}", 0, 0);
      }
      
      await bluetooth.printCustom("TOTAL A PAGAR: \$${total.toStringAsFixed(2)}", 1, 0);
      await bluetooth.printCustom("Tipo de pago: ${isCredit ? 'Crédito' : 'Contado'}", 0, 0);
      
      // Información de crédito (solo para reimpresiones)
      if (isCredit && isReprint) {
        await bluetooth.printNewLine();
        await bluetooth.printCustom("--------------------------------", 0, 1);
        
        // Mostrar estado de crédito
        if (creditStatus.isNotEmpty) {
          await bluetooth.printCustom(creditStatus, 1, 1);
        }
        
        // Si hay pago parcial, mostrar desglose
        if (amountPaid > 0 && amountPaid < total) {
          await bluetooth.printCustom("Pagado: \$${amountPaid.toStringAsFixed(2)}", 0, 0);
          await bluetooth.printCustom("Pendiente: \$${(total - amountPaid).toStringAsFixed(2)}", 0, 0);
        }
      }
      
      await bluetooth.printNewLine();
      
      // Pie de página
      await bluetooth.printCustom("¡Gracias por preferirnos!", 0, 1);
      await bluetooth.printNewLine();
      await bluetooth.printNewLine();
      await bluetooth.printNewLine();
      
    } catch (e) {
      print('❌ Error al imprimir factura como texto: $e');
    }
  }
}