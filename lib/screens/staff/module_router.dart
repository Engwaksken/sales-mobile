import 'package:flutter/material.dart';

import '../customer_notifications_screen.dart';
import '../expenses_screen.dart';
import 'catalog_screens.dart';
import 'chat_screens.dart';
import 'order_screens.dart';
import 'report_screens.dart';
import 'sales_screens.dart';
import 'stock_screens.dart';

/// Opens the screen behind a dashboard card, with the card's filter applied.
/// [module] and [filter] come from the server's stat (e.g. 'orders', {status: pending}).
Future<void> openStatTarget(BuildContext context, String module, Map<String, dynamic> filter, String title) {
  String? text(String key) => filter[key] == null ? null : '${filter[key]}';

  Widget? body;
  Widget? page;
  switch (module) {
    case 'sales':
      body = SalesScreen(initialStatus: text('status'), from: text('from'), to: text('to'));
    case 'payments':
      body = PaymentsScreen(initialStatus: text('status'), from: text('from'), to: text('to'));
    case 'orders':
      body = OrdersScreen(initialStatus: text('status'));
    case 'stock':
      body = StockScreen(lowOnly: '${filter['low']}' == '1' || filter['low'] == true);
    case 'expenses':
      body = const ExpensesScreen();
    case 'products':
      body = const ProductsScreen();
    case 'customers':
      body = CatalogScreen(config: CatalogConfig.customers);
    case 'chats':
      body = ChatsScreen(initialStatus: text('status'));
    case 'report':
      page = ReportViewScreen(type: text('type') ?? 'overview', label: title);
    case 'notifications':
      page = const CustomerNotificationsScreen();
  }

  if (page == null && body == null) return Future.value();
  return Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => page ?? Scaffold(appBar: AppBar(title: Text(title)), body: body)),
  );
}
