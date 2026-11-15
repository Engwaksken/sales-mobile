import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nsales_native/core/api_client.dart';
import 'package:nsales_native/core/auth_store.dart';
import 'package:nsales_native/core/branding.dart';
import 'package:nsales_native/core/format.dart';
import 'package:nsales_native/core/staff_lookups.dart';
import 'package:nsales_native/core/user_access.dart';
import 'package:nsales_native/screens/customer_home_screen.dart';
import 'package:nsales_native/screens/home_screen.dart';
import 'package:nsales_native/screens/staff_home_screen.dart';
import 'package:provider/provider.dart';

Future<void> pumpHome(WidgetTester tester, Map<String, dynamic> user) async {
  const storage = FlutterSecureStorage();
  final api = ApiClient(storage)..setSessionToken('test-token');
  // Stand-in server: every request succeeds with an empty payload.
  api.dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) => handler.resolve(
      Response(requestOptions: options, statusCode: 200, data: <String, dynamic>{}),
    ),
  ));
  final auth = AuthStore(api, storage)
    ..user = user
    ..authenticated = true
    ..loading = false;

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: api),
        ChangeNotifierProvider<AuthStore>.value(value: auth),
        ChangeNotifierProvider<StaffLookups>(create: (_) => StaffLookups(api)),
        ChangeNotifierProvider<BrandingStore>(create: (_) => BrandingStore(api, storage)),
      ],
      child: const MaterialApp(home: HomeScreen()),
    ),
  );
  await tester.pump();
}

/// Screens fire API calls on open; tear the tree down and let Dio's
/// timeout timers run out so the test ends cleanly.
Future<void> drainTimers(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 35));
}

Finder navLabel(String label) => find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(label),
    );

void main() {
  group('UserAccess', () {
    test('admin can do everything', () {
      expect(const UserAccess({'role': 'admin'}).can('manage_stock'), isTrue);
    });

    test('staff need the exact permission', () {
      const access = UserAccess({
        'role': 'cashier',
        'permissions': ['manage_sales'],
      });
      expect(access.can('manage_sales'), isTrue);
      expect(access.can('manage_stock'), isFalse);
      expect(access.isCustomer, isFalse);
    });

    test('missing role is treated as customer', () {
      expect(const UserAccess({}).isCustomer, isTrue);
    });
  });

  group('format', () {
    test('money groups thousands', () {
      expect(money(1250000), 'UGX 1,250,000');
      expect(money('820.5'), 'UGX 820.50');
    });

    test('compact money stays short', () {
      expect(compactMoney(1250000), 'UGX 1.25M');
      expect(compactMoney(45000), 'UGX 45K');
      expect(compactMoney(900), 'UGX 900');
    });
  });

  group('allowedModules', () {
    List<String> ids(Map<String, dynamic> user) => allowedModules(UserAccess(user)).map((m) => m.id).toList();

    test('admin gets every module', () {
      expect(ids({'role': 'admin'}).length, staffModules.length);
    });

    test('a store keeper only gets stock and reports', () {
      expect(ids({'role': 'manager', 'permissions': ['manage_stock']}), ['stock', 'unit-types', 'reports']);
    });

    test('only owners with view_activity_logs see the activity log', () {
      expect(ids({'role': 'cashier', 'permissions': ['manage_sales']}), isNot(contains('activity')));
      expect(ids({'role': 'manager', 'permissions': ['view_activity_logs']}), contains('activity'));
      expect(ids({'role': 'admin'}), contains('activity'));
    });

    test('accounting modules need manage_statements', () {
      final accountant = ids({'role': 'accountant', 'permissions': ['manage_statements', 'manage_expenses']});
      expect(accountant, containsAll(['chart-of-accounts', 'journals', 'expenses', 'expense-categories']));
      expect(accountant, isNot(contains('sales')));
    });
  });

  testWidgets('customers get the shop experience', (tester) async {
    await pumpHome(tester, {'name': 'Buyer', 'role': 'customer'});

    expect(find.byType(CustomerHomeScreen), findsOneWidget);
    expect(find.byType(StaffHomeScreen), findsNothing);
    await drainTimers(tester);
  });

  testWidgets('admins get the staff workspace with every module', (tester) async {
    await pumpHome(tester, {'name': 'Admin', 'role': 'admin', 'permissions': ['*']});

    expect(find.byType(StaffHomeScreen), findsOneWidget);
    for (final label in ['Dashboard', 'Sales', 'Stock', 'Orders', 'More']) {
      expect(navLabel(label), findsOneWidget, reason: label);
    }

    await tester.tap(navLabel('More'));
    await tester.pump();
    final moreList = find.descendant(of: find.byType(StaffMoreScreen), matching: find.byType(Scrollable)).first;
    for (final label in ['Payments', 'Products', 'Expenses', 'Customers', 'Reports', 'Activity Log', 'Users']) {
      final tile = find.widgetWithText(ListTile, label);
      await tester.scrollUntilVisible(tile, 200, scrollable: moreList);
      expect(tile, findsOneWidget, reason: label);
    }
    await drainTimers(tester);
  });

  testWidgets('a cashier only sees the modules their role allows', (tester) async {
    await pumpHome(tester, {
      'name': 'Grace',
      'role': 'cashier',
      'permissions': ['manage_sales', 'manage_expenses'],
    });

    expect(navLabel('Sales'), findsOneWidget);
    expect(navLabel('Expenses'), findsOneWidget);
    expect(navLabel('Stock'), findsNothing);
    expect(navLabel('Orders'), findsNothing);
    // Payments rides on manage_sales and takes the last bar slot.
    expect(navLabel('Payments'), findsOneWidget);
    await drainTimers(tester);
  });
}
