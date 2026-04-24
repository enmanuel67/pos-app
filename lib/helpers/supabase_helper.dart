import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseHelper {
  static SupabaseClient get client => Supabase.instance.client;

  static const tablesToCheck = <String>[
    'suppliers',
    'products',
    'clients',
    'sales',
    'sale_items',
    'inventory_entries',
    'expenses',
    'expense_entries',
    'payment_history',
    'app_error_logs',
    'inventory_drafts',
  ];

  static Future<Map<String, int>> getTableCounts() async {
    final counts = <String, int>{};

    for (final table in tablesToCheck) {
      counts[table] = await client.from(table).count();
    }

    return counts;
  }
}
