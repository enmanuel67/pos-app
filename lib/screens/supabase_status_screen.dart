import 'package:flutter/material.dart';
import 'package:pos_app/helpers/error_logger.dart';
import 'package:pos_app/helpers/supabase_helper.dart';

class SupabaseStatusScreen extends StatefulWidget {
  const SupabaseStatusScreen({super.key});

  @override
  State<SupabaseStatusScreen> createState() => _SupabaseStatusScreenState();
}

class _SupabaseStatusScreenState extends State<SupabaseStatusScreen> {
  late Future<Map<String, int>> _countsFuture;

  @override
  void initState() {
    super.initState();
    _countsFuture = SupabaseHelper.getTableCounts();
  }

  void _reload() {
    setState(() {
      _countsFuture = SupabaseHelper.getTableCounts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conexion Supabase'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, int>>(
        future: _countsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            final error = snapshot.error ?? 'Error desconocido';
            ErrorLogger.log(
              source: 'SupabaseStatusScreen',
              error: error,
              stackTrace: snapshot.stackTrace,
              details: 'Probando conexion y conteos de Supabase',
            );

            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.cloud_off, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  const Text(
                    'No se pudo conectar con Supabase.',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text('$error'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Intentar otra vez'),
                  ),
                ],
              ),
            );
          }

          final counts = snapshot.data ?? {};
          final totalVisibleRows = counts.values.fold<int>(
            0,
            (sum, count) => sum + count,
          );
          final canSeeData = totalVisibleRows > 0;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color:
                    canSeeData ? Colors.green.shade50 : Colors.orange.shade50,
                child: ListTile(
                  leading: Icon(
                    canSeeData ? Icons.cloud_done : Icons.lock_outline,
                    color: canSeeData ? Colors.green : Colors.orange,
                  ),
                  title: Text(
                    canSeeData
                        ? 'Conexion activa'
                        : 'Conexion activa, datos no visibles',
                  ),
                  subtitle: Text(
                    canSeeData
                        ? 'La app pudo leer datos desde Supabase.'
                        : 'La llave anon conecta, pero las politicas/RLS no permiten leer filas.',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ...SupabaseHelper.tablesToCheck.map(
                (table) => Card(
                  child: ListTile(
                    title: Text(table),
                    trailing: Text(
                      '${counts[table] ?? 0}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
