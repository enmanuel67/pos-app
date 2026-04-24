import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../db/db_helper.dart';

class DatabaseBackupResult {
  final String path;
  final Map<String, int> counts;

  DatabaseBackupResult({
    required this.path,
    required this.counts,
  });
}

class DatabaseBackupHelper {
  static const MethodChannel _channel = MethodChannel('com.example.pos_app/backup');

  static Future<DatabaseBackupResult> createBackup() async {
    await DBHelper.db;

    final dbPath = join(await getDatabasesPath(), 'pos.db');
    final counts = await _getTableCounts();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'pos_backup_$timestamp.db';

    final result = await _channel.invokeMethod<String>(
      'backupDatabaseToDownloads',
      {
        'sourcePath': dbPath,
        'fileName': fileName,
      },
    );

    if (result == null || result.trim().isEmpty) {
      throw Exception('No se pudo crear el backup');
    }

    return DatabaseBackupResult(
      path: result,
      counts: counts,
    );
  }

  static Future<Map<String, int>> _getTableCounts() async {
    final dbClient = await DBHelper.db;
    final tables = [
      'products',
      'clients',
      'suppliers',
      'sales',
      'sale_items',
      'inventory_entries',
      'expenses',
      'expense_entries',
      'payment_history',
    ];

    final counts = <String, int>{};

    for (final table in tables) {
      try {
        final result = await dbClient.rawQuery('SELECT COUNT(*) AS total FROM $table');
        counts[table] = (result.first['total'] as int?) ?? 0;
      } catch (_) {
        counts[table] = -1;
      }
    }

    return counts;
  }
}
