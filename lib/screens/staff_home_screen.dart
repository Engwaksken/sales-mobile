import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/auth_store.dart';
import '../core/config.dart';
import '../core/customer_api.dart';
import '../core/staff_lookups.dart';
import '../core/user_access.dart';
import 'customer_notifications_screen.dart';
import 'dashboard_screen.dart';
import 'expenses_screen.dart';
import 'resource_list_screen.dart';
import 'staff/catalog_screens.dart';
import 'staff/chat_screens.dart';
import 'staff/order_screens.dart';
import 'staff/report_screens.dart';
import 'staff/sales_screens.dart';
import 'staff/stock_screens.dart';

/// One area of the staff workspace. [permission] is the website's permission key
/// that unlocks it (admins pass everything); null means every staff member.
class StaffModule {
  const StaffModule({
    required this.id,
    required this.label,
    required this.group,
    required this.icon,
    required this.selectedIcon,
    required this.builder,
    this.permission,
    this.viewOnly = false,
  });

  final String id;
  final String label;
  final String group;
  final IconData icon;
  final IconData selectedIcon;
  final String? permission;

  /// Browsable in the app; changes are made on the website.
  final bool viewOnly;
  final WidgetBuilder builder;
}

Widget _viewOnly(String resource, String title, IconData icon) =>
    ResourceListScreen(resource: resource, title: title, icon: icon, showHeader: false);

/// Mirrors the website sidebar (groups and permission keys).
final List<StaffModule> staffModules = [
  StaffModule(
    id: 'sales', label: 'Sales', group: 'Sales', permission: 'manage_sales',
    icon: Icons.point_of_sale_outlined, selectedIcon: Icons.point_of_sale,
    builder: (_) => const SalesScreen(),
  ),
  StaffModule(
    id: 'orders', label: 'Orders', group: 'Sales', permission: 'manage_orders',
    icon: Icons.local_shipping_outlined, selectedIcon: Icons.local_shipping,
    builder: (_) => const OrdersScreen(),
  ),
  StaffModule(
    id: 'payments', label: 'Payments', group: 'Sales', permission: 'manage_sales',
    icon: Icons.payments_outlined, selectedIcon: Icons.payments,
    builder: (_) => const PaymentsScreen(),
  ),
  StaffModule(
    id: 'mobile-money', label: 'Mobile Money', group: 'Sales', permission: 'manage_sales', viewOnly: true,
    icon: Icons.phone_android_outlined, selectedIcon: Icons.phone_android,
    builder: (_) => _viewOnly('mobile-money', 'Mobile Money', Icons.phone_android),
  ),
  StaffModule(
    id: 'chats', label: 'Chats', group: 'Support', permission: 'manage_chats',
    icon: Icons.forum_outlined, selectedIcon: Icons.forum,
    builder: (_) => const ChatsScreen(),
  ),
  StaffModule(
    id: 'products', label: 'Products', group: 'Catalog', permission: 'manage_products',
    icon: Icons.category_outlined, selectedIcon: Icons.category,
    builder: (_) => const ProductsScreen(),
  ),
  StaffModule(
    id: 'categories', label: 'Categories', group: 'Catalog', permission: 'manage_categories',
    icon: Icons.sell_outlined, selectedIcon: Icons.sell,
    builder: (_) => CatalogScreen(config: CatalogConfig.categories),
  ),
  StaffModule(
    id: 'stock', label: 'Stock', group: 'Catalog', permission: 'manage_stock',
    icon: Icons.inventory_2_outlined, selectedIcon: Icons.inventory_2,
    builder: (_) => const StockScreen(),
  ),
  StaffModule(
    id: 'suppliers', label: 'Suppliers', group: 'Purchasing', permission: 'manage_suppliers',
    icon: Icons.local_shipping_outlined, selectedIcon: Icons.local_shipping,
    builder: (_) => CatalogScreen(config: CatalogConfig.suppliers),
  ),
  StaffModule(
    id: 'expenses', label: 'Expenses', group: 'Purchasing', permission: 'manage_expenses',
    icon: Icons.receipt_long_outlined, selectedIcon: Icons.receipt_long,
    builder: (_) => const ExpensesScreen(),
  ),
  StaffModule(
    id: 'expense-categories', label: 'Expense Categories', group: 'Purchasing', permission: 'manage_expenses',
    icon: Icons.folder_outlined, selectedIcon: Icons.folder,
    builder: (_) => CatalogScreen(config: CatalogConfig.expenseCategories),
  ),
  StaffModule(
    id: 'customers', label: 'Customers', group: 'Customers', permission: 'manage_customers',
    icon: Icons.people_outline, selectedIcon: Icons.people,
    builder: (_) => CatalogScreen(config: CatalogConfig.customers),
  ),
  StaffModule(
    id: 'reports', label: 'Reports', group: 'Reports & Accounting',
    icon: Icons.insights_outlined, selectedIcon: Icons.insights,
    builder: (_) => const ReportsScreen(),
  ),
  StaffModule(
    id: 'chart-of-accounts', label: 'Chart of Accounts', group: 'Reports & Accounting', permission: 'manage_statements', viewOnly: true,
    icon: Icons.account_tree_outlined, selectedIcon: Icons.account_tree,
    builder: (_) => _viewOnly('chart-of-accounts', 'Chart of Accounts', Icons.account_tree),
  ),
  StaffModule(
    id: 'journals', label: 'Journals', group: 'Reports & Accounting', permission: 'manage_statements', viewOnly: true,
    icon: Icons.menu_book_outlined, selectedIcon: Icons.menu_book,
    builder: (_) => _viewOnly('accounting-journals', 'Journals', Icons.menu_book),
  ),
  StaffModule(
    id: 'efris', label: 'EFRIS Invoices', group: 'Admin', permission: 'manage_settings', viewOnly: true,
    icon: Icons.verified_outlined, selectedIcon: Icons.verified,
    builder: (_) => _viewOnly('efris-invoices', 'EFRIS Invoices', Icons.verified),
  ),
  StaffModule(
    id: 'users', label: 'Users', group: 'Admin', permission: 'manage_users', viewOnly: true,
    icon: Icons.manage_accounts_outlined, selectedIcon: Icons.manage_accounts,
    builder: (_) => _viewOnly('users', 'Users', Icons.manage_accounts),
  ),
  StaffModule(
    id: 'branches', label: 'Branches', group: 'Admin', permission: 'manage_branches', viewOnly: true,
    icon: Icons.store_outlined, selectedIcon: Icons.store,
    builder: (_) => _viewOnly('branches', 'Branches', Icons.store),
  ),
  StaffModule(
    id: 'delivery-zones', label: 'Delivery Zones', group: 'Admin', permission: 'manage_settings', viewOnly: true,
    icon: Icons.map_outlined, selectedIcon: Icons.map,
    builder: (_) => _viewOnly('delivery-zones', 'Delivery Zones', Icons.map),
  ),
];

/// Bottom-bar candidates in order of everyday use; the first [barSlots] allowed ones are shown.
const _barPriority = ['sales', 'orders', 'stock', 'expenses', 'products', 'payments', 'customers', 'chats'];

List<StaffModule> allowedModules(UserAccess access) =>
    staffModules.where((m) => m.permission == null || access.can(m.permission!)).toList();

class StaffHomeScreen extends StatefulWidget {
  const StaffHomeScreen({super.key});

  @override
  State<StaffHomeScreen> createState() => _StaffHomeScreenState();
}

class _StaffHomeScreenState extends State<StaffHomeScreen> {
  static const int barSlots = 3;

  int index = 0;
  int unread = 0;
  late final CustomerApi notificationsApi;

  @override
  void initState() {
    super.initState();
    notificationsApi = CustomerApi(context.read<ApiClient>());
    // Fresh pick-lists for whoever just signed in.
    context.read<StaffLookups>().load();
    loadUnread();
  }

  Future<void> loadUnread() async {
    try {
      final value = await notificationsApi.unreadNotifications();
      if (mounted) setState(() => unread = value);
    } catch (_) {}
  }

  Future<void> openNotifications() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CustomerNotificationsScreen()));
    await loadUnread();
  }

  @override
  Widget build(BuildContext context) {
    final access = UserAccess(context.watch<AuthStore>().user);
    final allowed = allowedModules(access);
    final inBar = [
      for (final id in _barPriority) ...allowed.where((m) => m.id == id),
    ].take(barSlots).toList();
    final inMore = allowed.where((m) => !inBar.contains(m)).toList();

    final pages = <Widget>[
      const DashboardScreen(),
      for (final m in inBar) Builder(builder: m.builder),
      StaffMoreScreen(modules: inMore, access: access, onNotifications: openNotifications, unread: unread),
    ];
    final safeIndex = index.clamp(0, pages.length - 1);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            Image.asset(AppConfig.logoAsset, width: 34, height: 34, fit: BoxFit.contain),
            const SizedBox(width: 9),
            Flexible(
              child: Text(
                safeIndex == 0 || safeIndex == pages.length - 1 ? AppConfig.appName : inBar[safeIndex - 1].label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: openNotifications,
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text(unread > 99 ? '99+' : '$unread'),
              child: const Icon(Icons.notifications_outlined),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle_outlined),
            onSelected: (value) async {
              if (value == 'more') {
                setState(() => index = pages.length - 1);
              } else if (value == 'logout') {
                await context.read<AuthStore>().logout();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(access.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text(access.roleLabel, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'more',
                child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.apps), title: Text('All modules')),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.logout), title: Text('Logout')),
              ),
            ],
          ),
        ],
      ),
      body: IndexedStack(index: safeIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
          for (final m in inBar) NavigationDestination(icon: Icon(m.icon), selectedIcon: Icon(m.selectedIcon), label: m.label),
          const NavigationDestination(icon: Icon(Icons.apps_outlined), selectedIcon: Icon(Icons.apps), label: 'More'),
        ],
      ),
    );
  }
}

/// Every other module the user may open, grouped like the website sidebar.
class StaffMoreScreen extends StatelessWidget {
  const StaffMoreScreen({super.key, required this.modules, required this.access, this.onNotifications, this.unread = 0});

  final List<StaffModule> modules;
  final UserAccess access;
  final VoidCallback? onNotifications;
  final int unread;

  void open(BuildContext context, StaffModule module) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: Text(module.label),
            bottom: module.viewOnly
                ? const PreferredSize(
                    preferredSize: Size.fromHeight(26),
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text('View only · make changes on the website', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ),
                  )
                : null,
          ),
          body: Builder(builder: module.builder),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final groups = <String, List<StaffModule>>{};
    for (final m in modules) {
      groups.putIfAbsent(m.group, () => []).add(m);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: scheme.primaryContainer,
                  child: Text(
                    access.name.isNotEmpty ? access.name[0].toUpperCase() : '?',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: scheme.primary),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(access.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                      if (access.email.isNotEmpty) Text(access.email, style: const TextStyle(color: Color(0xFF64748B))),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(999)),
                        child: Text(access.roleLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: scheme.primary)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        for (final entry in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 18, bottom: 8),
            child: Text(entry.key.toUpperCase(), style: const TextStyle(fontSize: 12, letterSpacing: 0.6, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
          ),
          Card(
            child: Column(
              children: [
                for (final module in entry.value)
                  ListTile(
                    leading: Icon(module.icon),
                    title: Text(module.label),
                    subtitle: module.viewOnly ? const Text('View only') : null,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => open(context, module),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 18),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: Badge(isLabelVisible: unread > 0, label: Text('$unread'), child: const Icon(Icons.notifications_outlined)),
                title: const Text('Notifications'),
                trailing: const Icon(Icons.chevron_right),
                onTap: onNotifications,
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: Color(0xFFDC2626)),
                title: const Text('Logout', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w700)),
                onTap: () => context.read<AuthStore>().logout(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
