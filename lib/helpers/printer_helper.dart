import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class PrinterHelper {
  static final BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;
  static bool _isConnecting = false;

  static List<String> _wrapText(String text, int maxChars) {
    final words = text.trim().split(RegExp(r'\s+'));
    final lines = <String>[];
    var current = '';

    for (final word in words) {
      if (current.isEmpty) {
        current = word;
        continue;
      }

      final candidate = '$current $word';
      if (candidate.length <= maxChars) {
        current = candidate;
      } else {
        lines.add(current);
        current = word;
      }
    }

    if (current.isNotEmpty) {
      lines.add(current);
    }

    return lines;
  }

  static bool _looksLikePrinter(BluetoothDevice device) {
    final name = (device.name ?? '').toLowerCase();
    if (name.isEmpty) return false;
    return name.contains('printer') ||
        name.contains('print') ||
        name.contains('pos') ||
        name.contains('inner') ||
        name.contains('bt');
  }

  static Future<bool> connectToPrinter() async {
    if (_isConnecting) return false;

    try {
      _isConnecting = true;
      final isConnected =
          await bluetooth.isConnected.timeout(const Duration(seconds: 3)) ??
          false;
      if (isConnected) return true;

      final devices = await bluetooth.getBondedDevices().timeout(
        const Duration(seconds: 6),
      );
      if (devices.isEmpty) {
        print('No hay impresoras Bluetooth vinculadas.');
        return false;
      }

      final orderedDevices = <BluetoothDevice>[
        ...devices.where(_looksLikePrinter),
        ...devices.where((device) => !_looksLikePrinter(device)),
      ];

      for (final device in orderedDevices) {
        try {
          print('Intentando conectar a: ${device.name} (${device.address})');
          await bluetooth.connect(device).timeout(const Duration(seconds: 8));
          await Future.delayed(const Duration(seconds: 2));

          final connected =
              await bluetooth.isConnected.timeout(const Duration(seconds: 3)) ??
              false;
          if (connected) {
            print('Conectado a la impresora: ${device.name}');
            return true;
          }
        } catch (e) {
          print('Fallo conexion con ${device.name}: $e');
        }
      }

      print('No se pudo conectar a ninguna impresora vinculada.');
      return false;
    } catch (e) {
      print('Error al conectar con la impresora: $e');
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
        print('No hay conexion a impresora.');
        return;
      }

      final imageBytes = await captureWidgetAsImage(previewKey);
      if (imageBytes != null) {
        await printImage(imageBytes);
      } else {
        print('No se pudo capturar la imagen del sticker.');
      }
    } catch (e) {
      print('Error al imprimir sticker: $e');
    }
  }

  static Future<void> printMultipleStickers({
    required int cantidad,
    required GlobalKey previewKey,
  }) async {
    try {
      final connected = await connectToPrinter();
      if (!connected) {
        print('No hay conexion a impresora.');
        return;
      }

      final imageBytes = await captureWidgetAsImage(previewKey);
      if (imageBytes == null) {
        print('No se pudo capturar la imagen de los stickers.');
        return;
      }

      for (int i = 0; i < cantidad; i++) {
        await printImage(imageBytes);
        await printNewLines(4);
        await Future.delayed(const Duration(milliseconds: 800));
      }
    } catch (e) {
      print('Error al imprimir multiples stickers: $e');
    }
  }

  static Future<void> printImage(Uint8List imageBytes) async {
    try {
      final isConnected = await bluetooth.isConnected ?? false;
      if (!isConnected) {
        final connected = await connectToPrinter();
        if (!connected) return;
      }

      print('Imprimiendo imagen de ${imageBytes.length} bytes...');
      await bluetooth.printImageBytes(imageBytes);
      print('Imagen enviada a la impresora.');
    } catch (e) {
      print('Error al imprimir imagen: $e');
    }
  }

  static Future<void> printNewLines(int count) async {
    try {
      for (int i = 0; i < count; i++) {
        await bluetooth.printCustom('', 1, 1);
      }
    } catch (e) {
      print('Error al imprimir lineas nuevas: $e');
    }
  }

  static Future<Uint8List?> captureWidgetAsImage(GlobalKey key) async {
    try {
      await Future.delayed(const Duration(milliseconds: 300));

      final renderObject = key.currentContext?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) {
        print('No se pudo obtener un RenderRepaintBoundary valido.');
        print('Tipo de objeto obtenido: ${renderObject.runtimeType}');
        return null;
      }

      final boundary = renderObject;
      await Future.delayed(const Duration(milliseconds: 200));

      final image = await boundary.toImage(pixelRatio: 2.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        print('No se pudo convertir a ByteData.');
        return null;
      }

      print('Imagen capturada correctamente: ${image.width}x${image.height}');
      return byteData.buffer.asUint8List();
    } catch (e) {
      print('Error al capturar widget: $e');
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
      final byteData = await frame.image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      return byteData!.buffer.asUint8List();
    } catch (e) {
      print('Error al redimensionar imagen: $e');
      rethrow;
    }
  }

  static Future<void> disconnect() async {
    try {
      final isConnected = await bluetooth.isConnected ?? false;
      if (isConnected) {
        await bluetooth.disconnect();
        print('Desconectado de la impresora.');
      }
    } catch (e) {
      print('Error al desconectar: $e');
    }
  }

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
    bool isReprint = false,
    String creditStatus = "",
    double amountPaid = 0.0,
  }) async {
    try {
      final connected = await connectToPrinter();
      if (!connected) return;

      if (isReprint) {
        await bluetooth.printCustom("*** REIMPRESION ***", 1, 1);
      }

      await bluetooth.printCustom(businessName, 1, 1);
      for (final line in _wrapText(address, 30)) {
        await bluetooth.printCustom(line, 0, 1);
      }
      await bluetooth.printCustom(phone, 0, 1);
      await bluetooth.printNewLine();

      await bluetooth.printCustom("FACTURA #$invoiceNumber", 1, 1);
      await bluetooth.printCustom("Fecha: $date", 0, 1);
      await bluetooth.printCustom("--------------------------------", 0, 1);

      await bluetooth.printCustom("Cliente: $clientName", 0, 0);
      await bluetooth.printCustom("Tel: $clientPhone", 0, 0);
      await bluetooth.printCustom("--------------------------------", 0, 1);

      await bluetooth.printCustom("PRODUCTO", 0, 0);
      await bluetooth.printCustom("CANT  PRECIO   TOTAL", 0, 0);
      await bluetooth.printCustom("--------------------------------", 0, 1);

      for (final item in items) {
        final name = item['name'].toString();
        final qty = item['quantity'];
        final price = item['price'] as double;
        final subtotal = item['subtotal'] as double;

        for (final line in _wrapText(name, 30)) {
          await bluetooth.printCustom(line, 0, 0);
        }

        final detailLine =
            '${qty.toString().padRight(5)}'
            '\$${price.toStringAsFixed(2).padRight(8)}'
            '\$${subtotal.toStringAsFixed(2)}';

        await bluetooth.printCustom(detailLine, 0, 0);

        if (item['discount'] > 0) {
          await bluetooth.printCustom(
            "  Desc: \$${item['discount'].toStringAsFixed(2)}",
            0,
            0,
          );
        }

        await bluetooth.printCustom("", 0, 0);
      }

      await bluetooth.printCustom("--------------------------------", 0, 1);

      if (totalDiscount > 0) {
        await bluetooth.printCustom(
          "Descuento Total: \$${totalDiscount.toStringAsFixed(2)}",
          0,
          0,
        );
      }

      await bluetooth.printCustom(
        "TOTAL A PAGAR: \$${total.toStringAsFixed(2)}",
        1,
        0,
      );
      await bluetooth.printCustom(
        "Tipo de pago: ${isCredit ? 'Credito' : 'Contado'}",
        0,
        0,
      );

      if (isCredit && isReprint) {
        await bluetooth.printNewLine();
        await bluetooth.printCustom("--------------------------------", 0, 1);

        if (creditStatus.isNotEmpty) {
          await bluetooth.printCustom(creditStatus, 1, 1);
        }

        if (amountPaid > 0 && amountPaid < total) {
          await bluetooth.printCustom(
            "Pagado: \$${amountPaid.toStringAsFixed(2)}",
            0,
            0,
          );
          await bluetooth.printCustom(
            "Pendiente: \$${(total - amountPaid).toStringAsFixed(2)}",
            0,
            0,
          );
        }
      }

      await bluetooth.printNewLine();
      await bluetooth.printCustom("Gracias por preferirnos!", 0, 1);
      await bluetooth.printNewLine();
      await bluetooth.printNewLine();
      await bluetooth.printNewLine();
    } catch (e) {
      print('Error al imprimir factura como texto: $e');
    }
  }
}
