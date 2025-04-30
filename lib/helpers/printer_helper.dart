import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/material.dart'; // 👈 Para que reconozca GlobalKey


class PrinterHelper {
  static final BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;

  static Future<void> connectToPrinter() async {
    final isConnected = await bluetooth.isConnected ?? false;
    if (isConnected) return;

    List<BluetoothDevice> devices = await bluetooth.getBondedDevices();
    if (devices.isNotEmpty) {
      await bluetooth.connect(devices.first);
    }
  }

  static Future<void> printImage(Uint8List imageBytes) async {
    final isConnected = await bluetooth.isConnected ?? false;
    if (isConnected) {
      bluetooth.printImageBytes(imageBytes);
    }
  }

  // 👇 Esta es la función que debes llamar desde tu pantalla
  static Future<void> printSticker({
    required String name,
    required double price,
    required String barcodeData,
    required GlobalKey previewKey,
  }) async {
    try {
      await connectToPrinter();

      final boundary =
          previewKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('No se encontró el widget del sticker');

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      await printImage(pngBytes);
    } catch (e) {
      print('❌ Error al imprimir sticker: $e');
    }
  }

  static Future<void> disconnect() async {
    final isConnected = await bluetooth.isConnected ?? false;
    if (isConnected) {
      await bluetooth.disconnect();
    }
  }
}
