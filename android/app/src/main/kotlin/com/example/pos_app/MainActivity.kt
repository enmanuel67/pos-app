package com.example.pos_app

import android.Manifest
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.app.Activity
import android.content.ContentValues
import android.os.Bundle
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.content.pm.PackageManager
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.yourcompany.pos_app/scanner"
    private val BACKUP_CHANNEL = "com.example.pos_app/backup"
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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BACKUP_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "backupDatabaseToDownloads" -> {
                    val sourcePath = call.argument<String>("sourcePath")
                    val fileName = call.argument<String>("fileName")

                    if (sourcePath.isNullOrBlank() || fileName.isNullOrBlank()) {
                        result.error("INVALID_ARGUMENTS", "sourcePath y fileName son requeridos", null)
                        return@setMethodCallHandler
                    }

                    try {
                        val backupPath = backupDatabaseToDownloads(sourcePath, fileName)
                        result.success(backupPath)
                    } catch (e: Exception) {
                        result.error("BACKUP_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
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

    private fun backupDatabaseToDownloads(sourcePath: String, fileName: String): String {
        val sourceFile = File(sourcePath)
        if (!sourceFile.exists()) {
            throw Exception("No existe la base de datos en $sourcePath")
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                put(MediaStore.Downloads.MIME_TYPE, "application/octet-stream")
                put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
            }

            val resolver = applicationContext.contentResolver
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: throw Exception("No se pudo crear el archivo en Descargas")

            resolver.openOutputStream(uri)?.use { output ->
                FileInputStream(sourceFile).use { input ->
                    input.copyTo(output)
                }
            } ?: throw Exception("No se pudo abrir el archivo de backup")

            return "Descargas/$fileName"
        }

        val downloadsDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
        if (!downloadsDir.exists()) {
            downloadsDir.mkdirs()
        }
        val destinationFile = File(downloadsDir, fileName)
        FileInputStream(sourceFile).use { input ->
            FileOutputStream(destinationFile).use { output ->
                input.copyTo(output)
            }
        }

        return destinationFile.absolutePath
    }
}
