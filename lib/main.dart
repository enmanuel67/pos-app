import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
//import 'db/db_helper.dart';
import 'helpers/error_logger.dart';
import 'screens/bottom_nav_bar.dart';
import 'route_observer.dart';



/*void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DBHelper.deleteDatabaseFile(); // 🧨 Borra la base de datos vieja
  runApp(const MyApp());
} */


void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      ErrorLogger.log(
        source: 'FlutterError',
        error: details.exception,
        stackTrace: details.stack,
        details: details.context?.toDescription(),
      );
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      ErrorLogger.log(
        source: 'PlatformDispatcher',
        error: error,
        stackTrace: stack,
      );
      return true;
    };

    runApp(const MyApp());
  }, (error, stackTrace) {
    ErrorLogger.log(
      source: 'runZonedGuarded',
      error: error,
      stackTrace: stackTrace,
    );
  });
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
