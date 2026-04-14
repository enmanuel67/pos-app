import 'package:flutter/foundation.dart';
import 'package:pos_app/db/db_helper.dart';
import 'package:pos_app/models/app_error_log.dart';

class ErrorLogger {
  static Future<void> _ensureTable() async {
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

  static Future<void> log({
    required String source,
    required Object error,
    StackTrace? stackTrace,
    String? details,
  }) async {
    try {
      await _ensureTable();

      final entry = AppErrorLog(
        source: source,
        message: error.toString(),
        stackTrace: stackTrace?.toString(),
        details: details,
        createdAt: DateTime.now().toIso8601String(),
      );

      final dbClient = await DBHelper.db;
      await dbClient.insert('app_error_logs', entry.toMap());
    } catch (loggingError, loggingStack) {
      debugPrint('ErrorLogger fallo: $loggingError');
      debugPrint(loggingStack.toString());
    }
  }
}
