import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nsales_native/core/api_client.dart';
import 'package:nsales_native/core/staff_lookups.dart';
import 'package:nsales_native/screens/dashboard_screen.dart';
import 'package:nsales_native/screens/staff/order_screens.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('cards and charts render, and a card opens its filtered list', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    final api = ApiClient(const FlutterSecureStorage())..setSessionToken('t');
    final requests = <String>[];
    api.dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      requests.add('${options.path}?${options.queryParameters}');
      final data = options.path == '/dashboard'
          ? {
              'stats': [
                {'key': 'month_sales', 'label': 'Month Sales', 'value': 1250000, 'type': 'money', 'icon': 'trending_up', 'module': 'sales', 'filter': {'from': '2026-11-01', 'to': '2026-11-15'}},
                {'key': 'pending_orders', 'label': 'Pending Orders', 'value': 4, 'type': 'number', 'icon': 'shopping_cart', 'module': 'orders', 'filter': {'status': 'pending'}},
              ],
              'charts': {
                'monthly': [for (final m in ['May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov']) {'label': m, 'sales': 100000, 'expenses': 40000}],
                'daily': [for (var i = 0; i < 14; i++) {'label': '${i + 1} Nov', 'value': i * 1000}],
                'top_products': [{'name': 'Steel Bucket', 'quantity': 12, 'revenue': 120000}],
                'payment_methods': [{'label': 'Cash', 'value': 80000}, {'label': 'Mobile Money', 'value': 20000}],
                'order_stages': [{'key': 'pending', 'label': 'Received', 'value': 4}],
              },
              'recent_sales': [],
              'recent_orders': [],
            }
          : {'data': [], 'meta': {'current_page': 1, 'last_page': 1}};
      handler.resolve(Response(requestOptions: options, statusCode: 200, data: data));
    }));

    await tester.pumpWidget(MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: api),
        ChangeNotifierProvider<StaffLookups>(create: (_) => StaffLookups(api)),
      ],
      child: const MaterialApp(home: Scaffold(body: DashboardScreen())),
    ));
    await tester.pumpAndSettle();

    expect(find.text('UGX 1.25M'), findsOneWidget);
    expect(find.text('Sales vs expenses'), findsOneWidget);
    await tester.tap(find.text('Sales vs expenses').first);
    await tester.tap(find.text('Daily sales').first);
    await tester.tap(find.text('How customers paid').first);
    await tester.tap(find.text('Top products').first);
    await tester.pumpAndSettle();
    expect(find.byType(BarChart), findsOneWidget);
    expect(find.byType(LineChart), findsOneWidget);
    expect(find.byType(PieChart), findsOneWidget);
    expect(find.text('Steel Bucket'), findsOneWidget);

    await tester.tap(find.text('Pending Orders'));
    await tester.pumpAndSettle();

    expect(find.byType(OrdersScreen), findsOneWidget);
    expect(requests.any((r) => r.startsWith('/staff/orders?') && r.contains('status: pending')), isTrue);
  });
}
