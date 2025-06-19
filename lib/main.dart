import 'package:flutter/material.dart';
//import 'db/db_helper.dart';
import 'screens/bottom_nav_bar.dart';
import 'route_observer.dart';



/*void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DBHelper.deleteDatabaseFile(); // 🧨 Borra la base de datos vieja
  runApp(const MyApp());
} */


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'POS App',
      navigatorObservers: [routeObserver], // Aquí usas el RouteObserver
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        useMaterial3: true,
      ),
      home: BottomNavBar(), // ✅ Sin const
    );
  }
}
