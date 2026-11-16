import 'package:dio/dio.dart' show RequestOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nsales_native/screens/customer_orders_screen.dart';
import 'package:nsales_native/screens/expenses_screen.dart';
import 'package:nsales_native/screens/staff/activity_screens.dart';
import 'package:nsales_native/screens/staff/catalog_screens.dart';
import 'package:nsales_native/screens/staff/chat_screens.dart';
import 'package:nsales_native/screens/staff/order_screens.dart';
import 'package:nsales_native/screens/staff/report_screens.dart';
import 'package:nsales_native/screens/staff/sales_screens.dart';
import 'package:nsales_native/screens/staff/stock_screens.dart';
import 'package:nsales_native/widgets/filter_bar.dart';

import 'staff_harness.dart';

Widget framed(String title, Widget body) => Scaffold(appBar: AppBar(title: Text(title)), body: body);

String badge(WidgetTester tester) => tester
    .widget<Text>(find.descendant(of: find.byKey(const ValueKey('filter-bar-badge')), matching: find.byType(Text)))
    .data!;

Finder inSheet(Finder finder) => find.descendant(of: find.byType(FilterSheet), matching: finder);

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> openSheet(WidgetTester tester) => tapVisible(tester, find.byKey(const ValueKey('filter-bar-button')));

Future<void> applySheet(WidgetTester tester) => tapVisible(tester, find.byKey(const ValueKey('filter-sheet-apply')));

Future<void> pick(WidgetTester tester, String field, String option) async {
  await tapVisible(tester, inSheet(find.text(field)));
  await tapVisible(tester, find.text(option).last);
}

Future<void> removeChip(WidgetTester tester, String id) => tapVisible(
      tester,
      find.descendant(of: find.byKey(ValueKey('active-filter-$id')), matching: find.byIcon(Icons.close)),
    );

Object? listRows(RequestOptions r) => r.path.startsWith('/staff/reports/')
    ? {'headers': ['Name', 'Total'], 'keys': ['name', 'total'], 'money_columns': ['total'], 'rows': [{'name': 'Cash', 'total': 1000}], 'total_rows': 1}
    : page([
        {'id': 1, 'invoice_no': 'INV-1', 'receipt_no': 'RCT-1', 'payment_status': 'paid', 'status': 'paid', 'total_amount': 1000, 'amount': 1000, 'name': 'Jo'},
      ]);

void main() {
  setUp(() => filterClock = () => DateTime(2026, 11, 16, 9));
  tearDown(() => filterClock = DateTime.now);

  group('sales', () {
    testWidgets('a dashboard card\'s filters apply and show as active', (tester) async {
      final server = await pumpStaff(
        tester,
        framed('Sales', const SalesScreen(initialStatus: 'paid', from: '2026-11-01', to: '2026-11-15')),
        server: StaffServer(listRows),
      );

      expect(server.lastQuery('/staff/sales'), {'status': 'paid', 'from': '2026-11-01', 'to': '2026-11-15', 'page': 1});
      expect(badge(tester), '2');
      expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Paid')).selected, isTrue);
      expect(find.text('1 Nov – 15 Nov 2026'), findsOneWidget);

      await removeChip(tester, 'date');
      expect(server.lastQuery('/staff/sales'), {'status': 'paid', 'page': 1});
      expect(badge(tester), '1');

      await tapVisible(tester, find.widgetWithText(ChoiceChip, 'All'));
      expect(server.lastQuery('/staff/sales'), {'page': 1});
      expect(find.byKey(const ValueKey('filter-bar-badge')), findsNothing);
    });

    testWidgets('the sheet sets status and a date preset', (tester) async {
      final server = await pumpStaff(tester, framed('Sales', const SalesScreen()), server: StaffServer(listRows));
      expect(server.lastQuery('/staff/sales'), {'page': 1});

      await openSheet(tester);
      await tapVisible(tester, inSheet(find.text('Credit')));
      await tapVisible(tester, inSheet(find.text('Yesterday')));
      expect(server.queriesFor('/staff/sales'), hasLength(1), reason: 'nothing loads before Show results');

      await applySheet(tester);
      expect(server.lastQuery('/staff/sales'), {'status': 'pending', 'from': '2026-11-15', 'to': '2026-11-15', 'page': 1});
      expect(badge(tester), '2');
      expect(find.text('Yesterday'), findsOneWidget);

      await tapVisible(tester, find.text('Clear all'));
      expect(server.lastQuery('/staff/sales'), {'page': 1});
    });

    testWidgets('an empty filtered list offers to clear the filters', (tester) async {
      final server = await pumpStaff(
        tester,
        framed('Sales', const SalesScreen(initialStatus: 'outstanding')),
        server: StaffServer((r) => page(r.queryParameters['status'] == null ? [{'id': 1, 'invoice_no': 'INV-9', 'payment_status': 'paid'}] : [])),
      );

      expect(find.text('No results match these filters'), findsOneWidget);
      await tapVisible(tester, find.text('Clear filters'));
      expect(server.lastQuery('/staff/sales'), {'page': 1});
      expect(find.text('INV-9'), findsOneWidget);
      expect(find.text('No results match these filters'), findsNothing);
    });
  });

  testWidgets('payments: branch, method and product reach the API', (tester) async {
    final server = await pumpStaff(tester, framed('Payments', const PaymentsScreen()), server: StaffServer(listRows));
    expect(server.lastQuery('/staff/payments'), {'page': 1});

    await openSheet(tester);
    await tapVisible(tester, inSheet(find.text('Mobile Money')));
    await pick(tester, 'All branches', 'Kampala Road Wholesale and Retail Branch');
    await pick(tester, 'All products', 'Cement 50kg');
    await applySheet(tester);

    expect(server.lastQuery('/staff/payments'), {'branch_id': 2, 'payment_method': 'Mobile Money', 'product_id': 11, 'page': 1});
    expect(badge(tester), '3');
    expect(find.text('Product: Cement 50kg'), findsOneWidget);

    await removeChip(tester, 'product');
    expect(server.lastQuery('/staff/payments'), {'branch_id': 2, 'payment_method': 'Mobile Money', 'page': 1});

    await tapVisible(tester, find.text('Clear all'));
    expect(server.lastQuery('/staff/payments'), {'page': 1});
  });

  testWidgets('reports: this month by default, presets and filters change the request', (tester) async {
    final server = await pumpStaff(tester, const ReportViewScreen(type: 'sales', label: 'Sales report'), server: StaffServer(listRows));
    const path = '/staff/reports/sales';

    expect(server.lastQuery(path), {'from': '2026-11-01', 'to': '2026-11-16'});
    expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'This month')).selected, isTrue);
    expect(find.byKey(const ValueKey('filter-bar-badge')), findsNothing, reason: 'the default period is not a filter');

    await tapVisible(tester, find.widgetWithText(ChoiceChip, 'Last month'));
    expect(server.lastQuery(path), {'from': '2026-10-01', 'to': '2026-10-31'});
    expect(badge(tester), '1');

    await openSheet(tester);
    await pick(tester, 'All branches', 'Main Street');
    await tapVisible(tester, inSheet(find.text('Cash')));
    await applySheet(tester);
    expect(server.lastQuery(path), {'from': '2026-10-01', 'to': '2026-10-31', 'branch_id': 1, 'payment_method': 'Cash'});
    expect(badge(tester), '3');

    await tapVisible(tester, find.text('Clear all'));
    expect(server.lastQuery(path), {'from': '2026-11-01', 'to': '2026-11-16'});
  });

  testWidgets('starting filters on orders, chats and stock show as active', (tester) async {
    var server = await pumpStaff(tester, framed('Chats', const ChatsScreen()), server: StaffServer(listRows));
    expect(server.lastQuery('/staff/chats'), {'status': 'open', 'page': 1});
    expect(badge(tester), '1');
    expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Open')).selected, isTrue);

    server = await pumpStaff(tester, framed('Stock', const StockScreen(lowOnly: true)), server: StaffServer(listRows));
    expect(server.lastQuery('/staff/stock'), {'low': 1, 'page': 1});
    expect(badge(tester), '1');
    await tapVisible(tester, find.widgetWithText(ChoiceChip, 'Low stock'));
    expect(server.lastQuery('/staff/stock'), {'page': 1});

    server = await pumpStaff(tester, framed('Orders', const OrdersScreen(initialStatus: 'pending')), server: StaffServer(listRows));
    expect(server.lastQuery('/staff/orders'), {'status': 'pending', 'page': 1});
    expect(badge(tester), '1');
    // The stage names have not loaded, so the choice shows as a chip instead of a pill.
    expect(find.text('Stage: Pending'), findsOneWidget);
  });

  group('no overflow at 360 x 640 with text scale 1.3', () {
    final screens = <String, Widget Function()>{
      'sales': () => framed('Sales', const SalesScreen(initialStatus: 'partial', from: '2025-12-20', to: '2026-01-05')),
      'payments': () => framed('Payments', const PaymentsScreen()),
      'report': () => const ReportViewScreen(type: 'overview', label: 'Business overview report'),
      'orders': () => framed('Orders', const OrdersScreen(initialStatus: 'pending')),
      'chats': () => framed('Chats', const ChatsScreen()),
      'stock': () => framed('Stock', const StockScreen(lowOnly: true)),
      'products': () => framed('Products', const ProductsScreen()),
      'customers': () => framed('Customers', CatalogScreen(config: CatalogConfig.customers)),
      'activity': () => framed('Activity log', const ActivityLogScreen()),
      'expenses': () => framed('Expenses', const ExpensesScreen()),
      'customer orders': () => const Scaffold(body: CustomerOrdersScreen()),
    };

    for (final entry in screens.entries) {
      testWidgets(entry.key, (tester) async {
        await pumpStaff(tester, entry.value(), server: StaffServer(listRows), textScale: 1.3);
        expect(tester.takeException(), isNull);
        if (find.byKey(const ValueKey('filter-bar-button')).evaluate().isNotEmpty) {
          await openSheet(tester);
          expect(tester.takeException(), isNull);
          expect(find.byKey(const ValueKey('filter-sheet-apply')), findsOneWidget);
          await applySheet(tester);
        }
        expect(tester.takeException(), isNull);
      });
    }
  });
}
