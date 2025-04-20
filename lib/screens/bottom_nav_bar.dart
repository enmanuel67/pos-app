import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import '../models/product.dart';
import 'dashboard_screen.dart';
import 'notifications_screen.dart';
import '../route_observer.dart';

class BottomNavBar extends StatefulWidget {
  const BottomNavBar({Key? key}) : super(key: key);

  @override
  State<BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> with RouteAware {
  int _currentIndex = 0;
  List<Product> lowStockProducts = [];

  final PageController _pageController = PageController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
    _loadLowStockProducts();
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    // Se llama cuando se vuelve a esta pantalla desde otra
    _loadLowStockProducts();
  }

  Future<void> _loadLowStockProducts() async {
    final result = await DBHelper.getProducts();
    if (!mounted) return;

    setState(() {
      lowStockProducts = result.where((p) => p.quantity <= 5).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      const DashboardScreen(),
      const NotificationsScreen(),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (int index) async {
          setState(() {
            _currentIndex = index;
          });

          if (index == 0) {
            // Volvemos a dashboard
            await _loadLowStockProducts();
          }
        },
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                const Icon(Icons.notifications),
                if (lowStockProducts.isNotEmpty)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 13,
                        minHeight: 13,
                      ),
                      child: Text(
                        '${lowStockProducts.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            label: 'Notificaciones',
          ),
        ],
      ),
    );
  }
}
