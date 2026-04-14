import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pos_app/db/db_helper.dart';
import 'package:pos_app/models/app_error_log.dart';

class ErrorLogsScreen extends StatefulWidget {
  const ErrorLogsScreen({super.key});

  @override
  State<ErrorLogsScreen> createState() => _ErrorLogsScreenState();
}

class _ErrorLogsScreenState extends State<ErrorLogsScreen> {
  List<AppErrorLog> _logs = [];
  bool _loading = true;

  Future<void> _ensureTable() async {
    final dbClient = await DBHelper.db;
    await dbClient.execute('''
      CREATE TABLE IF NOT EXISTS app_error_logs(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        source TEXT,
        message TEXT,
        stack_trace TEXT,
        details TEXT,
        created_at TEXT
      );
    ''');
  }

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    await _ensureTable();
    final dbClient = await DBHelper.db;
    final rows = await dbClient.query(
      'app_error_logs',
      orderBy: 'datetime(created_at) DESC',
    );
    final logs = rows.map((e) => AppErrorLog.fromMap(e)).toList();
    if (!mounted) return;
    setState(() {
      _logs = logs;
      _loading = false;
    });
  }

  Future<void> _clearLogs() async {
    await _ensureTable();
    final dbClient = await DBHelper.db;
    await dbClient.delete('app_error_logs');
    await _loadLogs();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Registro de errores limpiado')),
    );
  }

  void _showDetails(AppErrorLog log) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(log.source),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Fecha: ${log.createdAt}'),
              const SizedBox(height: 12),
              const Text(
                'Mensaje',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(log.message),
              if (log.details != null && log.details!.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Detalle',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(log.details!),
              ],
              if (log.stackTrace != null && log.stackTrace!.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Stack trace',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SelectableText(log.stackTrace!),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registro de errores'),
        actions: [
          IconButton(
            onPressed: _loadLogs,
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar',
          ),
          IconButton(
            onPressed: _logs.isEmpty ? null : _clearLogs,
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Limpiar registro',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No hay errores guardados'),
                  ),
                )
              : ListView.separated(
                  itemCount: _logs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    final date = DateTime.tryParse(log.createdAt);
                    final dateLabel = date == null
                        ? log.createdAt
                        : DateFormat('yyyy-MM-dd HH:mm:ss').format(date);

                    return ListTile(
                      leading: const Icon(Icons.error_outline, color: Colors.red),
                      title: Text(log.source),
                      subtitle: Text(
                        '${log.message}\n$dateLabel',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      isThreeLine: true,
                      onTap: () => _showDetails(log),
                    );
                  },
                ),
    );
  }
}
