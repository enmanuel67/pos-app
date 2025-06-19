package com.example.pos_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.app.Activity
import android.os.Bundle

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.yourcompany.pos_app/scanner"
    private val SCAN_REQUEST_CODE = 100
    private var scanResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startScanner" -> {
                    scanResult = result
                    startDeviceScanner()
                }
                "openScannerApp" -> {
                    scanResult = result
                    openScannerApp()
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun startDeviceScanner() {
        try {
            // Intenta abrir la aplicación "Camera Scan" específica del dispositivo MJ-Q50
            val intent = Intent()
            intent.setAction("com.action.CAMERA_SCAN") // Esto puede variar según el dispositivo
            intent.putExtra("SCAN_MODE", "BARCODE") // Opcional: puede que necesites parámetros específicos
            
            startActivityForResult(intent, SCAN_REQUEST_CODE)
        } catch (e: Exception) {
            scanResult?.error("UNAVAILABLE", "No se pudo iniciar el escáner", null)
            scanResult = null
        }
    }

    private fun openScannerApp() {
        try {
            // Intenta abrir la aplicación de escaneo por su paquete
            val launchIntent = packageManager.getLaunchIntentForPackage("com.yourdevice.scanner")
            if (launchIntent != null) {
                startActivity(launchIntent)
                scanResult?.success("")
            } else {
                scanResult?.error("NOT_FOUND", "Aplicación de escaneo no encontrada", null)
            }
        } catch (e: Exception) {
            scanResult?.error("ERROR", "Error al abrir la aplicación de escaneo", null)
        }
        scanResult = null
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        
        if (requestCode == SCAN_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                // Obtiene el código de barras escaneado de los resultados
                val barcode = data.getStringExtra("SCAN_RESULT") ?: ""
                scanResult?.success(barcode)
            } else {
                scanResult?.error("CANCELLED", "Escaneo cancelado", null)
            }
            scanResult = null
        }
    }
}