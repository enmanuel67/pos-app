package com.example.pos_app

import android.Manifest
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.app.Activity
import android.os.Bundle
import android.os.Build
import android.content.pm.PackageManager

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.yourcompany.pos_app/scanner"
    private val SCAN_REQUEST_CODE = 100
    private val BLUETOOTH_PERMISSION_REQUEST_CODE = 200
    private var scanResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        requestBluetoothPermissionsIfNeeded()
    }

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

    private fun requestBluetoothPermissionsIfNeeded() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return

        val requiredPermissions = arrayOf(
            Manifest.permission.BLUETOOTH_CONNECT,
            Manifest.permission.BLUETOOTH_SCAN,
            Manifest.permission.ACCESS_FINE_LOCATION,
        )

        val missingPermissions = requiredPermissions.filter {
            checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED
        }

        if (missingPermissions.isNotEmpty()) {
            requestPermissions(
                missingPermissions.toTypedArray(),
                BLUETOOTH_PERMISSION_REQUEST_CODE
            )
        }
    }
}
