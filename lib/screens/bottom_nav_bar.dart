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
  int overdueInvoiceCount = 0;

  final PageController _pageController = PageController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
    _loadNotifications();
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final result = await DBHelper.getProducts();
    final overdue = await DBHelper.getOverdueCreditInvoices();

    if (!mounted) return;

    final filteredLowStock = result
    .where((p) => p.quantity <= 5 && (p.isRentable != true))
    .toList();

setState(() {
  lowStockProducts = filteredLowStock;
  overdueInvoiceCount = overdue.length;
});

  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      const DashboardScreen(),
      const NotificationsScreen(),
    ];

    final totalNotifications = lowStockProducts.length + overdueInvoiceCount;

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (int index) async {
          setState(() {
            _currentIndex = index;
          });

          if (index == 0) {
            await _loadNotifications();
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
                if (totalNotifications > 0)
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
                        '$totalNotifications',
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
