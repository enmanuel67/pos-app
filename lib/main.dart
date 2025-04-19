import 'package:flutter/material.dart';
import 'screens/dashboard_screen.dart';
import 'screens/suppliers_screen.dart';
import 'screens/create_supplier_screen.dart';
//import 'db/db_helper.dart';
import 'screens/bottom_nav_bar.dart';

//await DBHelper.deleteDatabaseFile(); // 👈 Borra la base de datos


void main() {
  runApp(const MaterialApp(
    home: BottomNavBar(),
    debugShowCheckedModeBanner: false,
  ));
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
