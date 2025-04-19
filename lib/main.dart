import 'package:flutter/material.dart';
import 'screens/dashboard_screen.dart';
import 'screens/suppliers_screen.dart';
import 'screens/create_supplier_screen.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'POS App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => DashboardScreen(),
        '/proveedores': (context) => SuppliersScreen(),
        '/create_supplier': (context) => CreateSupplierScreen(),
        // Aquí podrías ir agregando más rutas como:
        // '/productos': (context) => ProductsScreen(),
      },
    );
  }
}
