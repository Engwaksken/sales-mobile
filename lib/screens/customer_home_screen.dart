import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/branding.dart';
import '../core/api_client.dart';
import '../core/auth_store.dart';
import '../core/customer_api.dart';
import 'customer_dashboard_screen.dart';
import 'customer_orders_screen.dart';
import 'customer_products_screen.dart';
import 'customer_account_screen.dart';
import 'customer_notifications_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  int index = 0;
  int unread = 0;

  late final CustomerApi customerApi;

  @override
  void initState() {
    super.initState();
    customerApi = CustomerApi(context.read<ApiClient>());
    loadUnread();
  }

  Future<void> loadUnread() async {
    try {
      final value = await customerApi.unreadNotifications();
      if (mounted) setState(() => unread = value);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthStore>().user;

    final pages = [
      const CustomerDashboardScreen(),
      const CustomerProductsScreen(),
      const CustomerOrdersScreen(),
      CustomerAccountScreen(
        onOpenOrders: () => setState(() => index = 2),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            const BrandLogo(size: 34, favicon: true),
            const SizedBox(width: 9),
            Flexible(
              child: Text(
                context.brandName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Search products',
            onPressed: () => setState(() => index = 1),
            icon: const Icon(Icons.search),
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                tooltip: 'Notifications',
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CustomerNotificationsScreen(),
                    ),
                  );
                  await loadUnread();
                },
                icon: const Icon(Icons.notifications_outlined),
              ),
              if (unread > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: IgnorePointer(
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 18),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        unread > 99 ? '99+' : '$unread',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle_outlined),
            onSelected: (value) async {
              if (value == 'account') {
                setState(() => index = 3);
              } else if (value == 'logout') {
                await context.read<AuthStore>().logout();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Text(
                  '${user?['name'] ?? 'Customer'}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'account',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.person_outline),
                  title: Text('My Account'),
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.logout),
                  title: Text('Logout'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) {
          setState(() => index = value);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: 'Shop',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_shipping_outlined),
            selectedIcon: Icon(Icons.local_shipping),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Account',
          ),
        ],
      ),
    );
  }
}
