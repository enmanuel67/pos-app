import 'package:flutter/material.dart';
import 'package:pos_app/helpers/database_backup_helper.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _isBackingUp = false;
  String? _backupPath;
  Map<String, int> _counts = {};
  String? _error;

  String _tableLabel(String tableName) {
    switch (tableName) {
      case 'products':
        return 'Productos';
      case 'clients':
        return 'Clientes';
      case 'suppliers':
        return 'Proveedores';
      case 'sales':
        return 'Facturas / ventas';
      case 'sale_items':
        return 'Articulos vendidos';
      case 'inventory_entries':
        return 'Entradas de inventario';
      case 'expenses':
        return 'Tipos de gastos';
      case 'expense_entries':
        return 'Gastos registrados';
      case 'payment_history':
        return 'Pagos registrados';
      default:
        return tableName;
    }
  }

  Future<void> _createBackup() async {
    setState(() {
      _isBackingUp = true;
      _backupPath = null;
      _counts = {};
      _error = null;
    });

    try {
      final result = await DatabaseBackupHelper.createBackup();
      if (!mounted) return;
      setState(() {
        _backupPath = result.path;
        _counts = result.counts;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup creado correctamente')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creando backup: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isBackingUp = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup de datos')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Esto crea una copia del archivo pos.db en Descargas del dispositivo. '
              'No borra ni modifica tus datos actuales.',
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isBackingUp ? null : _createBackup,
                icon: _isBackingUp
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.backup),
                label: Text(_isBackingUp ? 'Creando backup...' : 'Crear backup'),
              ),
            ),
            if (_backupPath != null) ...[
              const SizedBox(height: 16),
              const Text(
                'Backup guardado en:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SelectableText(_backupPath!),
              const SizedBox(height: 16),
              const Text(
                'Datos incluidos en el backup:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ..._counts.entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text('${_tableLabel(entry.key)}: ${entry.value}'),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              const Text(
                'Error:',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
              ),
              SelectableText(_error!),
            ],
          ],
        ),
      ),
    );
  }
}
